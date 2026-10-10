#!/usr/bin/env python3
"""Bound an owned verification command, reserving the job's final diagnostic time."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import signal
import subprocess
import time
import uuid


def remaining(environment: dict[str, str], now: float) -> float | None:
    value = environment.get('TRINKET_CI_DEADLINE_EPOCH')
    if value is None:
        return None
    deadline = float(value)
    if not 0 < deadline < float('inf'):
        raise ValueError('Invalid CI deadline')
    return max(0, deadline - now)


def timeout_report(command: list[str], results: Path, environment: dict[str, str]) -> None:
    results.mkdir(parents=True, exist_ok=True)
    report = results / 'verification-budget-diagnostics.json'
    message = 'Verification exhausted its execution budget; diagnostic time remains reserved.'
    payload = {'schema_version': 1, 'label': 'verification-budget', 'action': 'verification',
               'status': 'failed', 'exit_code': 124, 'classification': 'tooling',
               'generated_at': datetime.now(timezone.utc).isoformat(),
               'session_id': environment.get('TRINKET_DIAGNOSTICS_SESSION_ID', ''),
               'issues': [{'kind': 'tooling', 'message': message, 'details': ' '.join(command)}]}
    report.write_text(json.dumps(payload) + '\n')
    (results / 'verification-budget-invocation.json').write_text(
        json.dumps({**payload, 'diagnostics_json': str(report)}) + '\n')
    print('::error::' + message, flush=True)


def run(command: list[str], environment: dict[str, str]) -> int:
    seconds = remaining(environment, time.time())
    if seconds is None:
        return subprocess.call(command, env=environment)
    environment = {**environment, 'TRINKET_DIAGNOSTICS_SESSION_ID': environment.get('TRINKET_DIAGNOSTICS_SESSION_ID') or 'ci-budget-' + uuid.uuid4().hex}
    results = Path(environment.get('RESULTS_DIR', '.DerivedData/TestResults')).resolve()
    if seconds <= 0:
        timeout_report(command, results, environment)
        return 124
    # Give xcode-runner time to produce its ordinary completion manifest first.
    env = {**environment, 'TRINKET_XCODE_WALL_TIMEOUT_SECONDS': str(max(1, int(seconds - 30)))}
    requested = environment.get('TRINKET_XCODE_WALL_TIMEOUT_SECONDS')
    if requested and requested.isdigit() and int(requested) > 0:
        env['TRINKET_XCODE_WALL_TIMEOUT_SECONDS'] = str(min(int(requested), int(env['TRINKET_XCODE_WALL_TIMEOUT_SECONDS'])))
    process = subprocess.Popen(command, env=env, start_new_session=True)

    def terminate() -> None:
        # This process group was created above; never select foreign Xcode guests.
        grace = time.monotonic() + 5
        try:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=5)
        except ProcessLookupError:
            pass
        except subprocess.TimeoutExpired:
            pass
        time.sleep(max(0, grace - time.monotonic()))
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()

    previous = {}
    def interrupted(signum, _frame):
        terminate()
        raise SystemExit(128 + signum)
    for signum in (signal.SIGTERM, signal.SIGINT):
        previous[signum] = signal.signal(signum, interrupted)
    try:
        try:
            return process.wait(timeout=remaining(environment, time.time()))
        except subprocess.TimeoutExpired:
            terminate()
            timeout_report(command, results, environment)
            return 124
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('A command is required')
    raise SystemExit(run(command, dict(os.environ)))


if __name__ == '__main__':
    main()
