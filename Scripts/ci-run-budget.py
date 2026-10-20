#!/usr/bin/env python3
"""Bound an owned verification command, reserving the job's final diagnostic time."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import signal
import shlex
import subprocess
import sys
import tempfile
import time
import uuid

from internal.diagnostics.diagnostic_model import CLASSIFICATION_PRECEDENCE, DiagnosticIssue, IssueObservation
from internal.diagnostics.failure_diagnostics_parsers import parse_log


def preparation_observations(log: Path, status: int, output: str, phase: str) -> tuple[str, list]:
    observations = [item for item in parse_log(log, status) if item.kind != 'unknown']
    inventory_phases = (
        ('Simulator guest process inspection failed:', 'simulator-process-inventory'),
        ('Output cleanup refused:', 'output-inventory'),
    )
    inventory = next((name for marker, name in inventory_phases if marker in output), '')
    # The generic log parser treats "inspection failed" as a test failure. These
    # safety checks run before tests; preserve real assertions/compiler errors if mixed in.
    if inventory:
        phase = inventory
        inventory_messages = (*[marker for marker, _ in inventory_phases], 'Simulator guest inventory attempt ')
        observations = [item for item in observations
                        if item.kind != 'test-failure'
                        or not any(marker in item.message for marker in inventory_messages)
                        or re.search(r'XCTAssert|XCTFail|[Aa]ssertion failed|[Ee]xpectation failed|Issue recorded:', item.message)]
        observations.append(IssueObservation('tooling', 'Preparation inventory', output.strip()[-2000:]))
    if phase == 'toolchain':
        observations = [IssueObservation('tooling', 'Xcode preparation', output.strip()[-2000:])]
    return phase, observations


def preparation_report(command: list[str], results: Path, environment: dict[str, str],
                       status: int, elapsed: float, output: str, phase: str) -> None:
    results.mkdir(parents=True, exist_ok=True)
    label = 'preparation-' + uuid.uuid4().hex[:12]
    log = results / 'raw' / (label + '.log')
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(output)
    phase, observations = preparation_observations(log, status, output, phase)
    if not observations:
        observations = [IssueObservation('unknown', 'Command preparation', output.strip()[-2000:] or
                                         f'{shlex.join(command)} exited {status} before recording an invocation')]
    kinds = {item.kind for item in observations}
    classification = next(kind for kind in CLASSIFICATION_PRECEDENCE if kind in kinds)
    identity = {key: environment.get(key, '') for key in
                ('ImageOS', 'ImageVersion', 'DEVELOPER_DIR', 'XCODE_VERSION', 'XCODE_BUILD', 'SIMULATOR_DESTINATION')}
    payload = {'schema_version': 1, 'label': label, 'action': 'prepare', 'phase': phase,
               'status': 'failed', 'exit_code': status, 'classification': classification,
               'command': command, 'duration_seconds': round(elapsed, 3), 'environment': identity,
               'generated_at': datetime.now(timezone.utc).isoformat(),
               'session_id': environment.get('TRINKET_DIAGNOSTICS_SESSION_ID', ''),
               'raw_log_path': str(log),
               'issues': [DiagnosticIssue.from_observation(item).to_dict() for item in observations]}
    report = results / (label + '-diagnostics.json')
    report.write_text(json.dumps(payload) + '\n')
    (results / (label + '-invocation.json')).write_text(json.dumps({**payload, 'diagnostics_json': str(report)}) + '\n')
    print(f"Preparation failed ({classification}, {elapsed:.1f}s): {shlex.join(command)}", flush=True)


def has_failure_receipt(results: Path, environment: dict[str, str], before: dict[Path, int]) -> bool:
    for path in results.glob('*-invocation.json'):
        try:
            if before.get(path) == path.stat().st_mtime_ns:
                continue
            manifest = json.loads(path.read_text())
            if (manifest.get('session_id') == environment.get('TRINKET_DIAGNOSTICS_SESSION_ID')
                    and manifest.get('status') == 'failed'):
                return True
        except (OSError, ValueError, AttributeError):
            continue
    return False


def remaining(environment: dict[str, str], now: float) -> float | None:
    value = environment.get('TRINKET_CI_DEADLINE_EPOCH')
    if value is None:
        return None
    deadline = float(value)
    if not 0 < deadline < float('inf'):
        raise ValueError('Invalid CI deadline')
    return max(0, deadline - now)


def timeout_report(command: list[str], results: Path, environment: dict[str, str],
                   elapsed: float = 0, output: str = '', phase: str = 'command-preparation') -> None:
    results.mkdir(parents=True, exist_ok=True)
    report = results / 'verification-budget-diagnostics.json'
    message = 'Verification exhausted its execution budget; diagnostic time remains reserved.'
    log = results / 'raw/verification-budget.log'
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(output)
    phase, observations = preparation_observations(log, 124, output, phase)
    observations.append(IssueObservation('tooling', 'Verification deadline', message, details=shlex.join(command)))
    kinds = {item.kind for item in observations}
    classification = next(kind for kind in CLASSIFICATION_PRECEDENCE if kind in kinds)
    payload = {'schema_version': 1, 'label': 'verification-budget', 'action': 'verification',
               'status': 'failed', 'exit_code': 124, 'classification': classification,
               'command': command, 'phase': phase, 'duration_seconds': round(elapsed, 3),
               'environment': {key: environment.get(key, '') for key in
                               ('ImageOS', 'ImageVersion', 'DEVELOPER_DIR', 'XCODE_VERSION', 'XCODE_BUILD', 'SIMULATOR_DESTINATION')},
               'raw_log_path': str(log),
               'generated_at': datetime.now(timezone.utc).isoformat(),
               'session_id': environment.get('TRINKET_DIAGNOSTICS_SESSION_ID', ''),
               'issues': [DiagnosticIssue.from_observation(item).to_dict() for item in observations]}
    report.write_text(json.dumps(payload) + '\n')
    (results / 'verification-budget-invocation.json').write_text(
        json.dumps({**payload, 'diagnostics_json': str(report)}) + '\n')
    print('::error::' + message, flush=True)


def run(command: list[str], environment: dict[str, str], phase: str = 'command-preparation') -> int:
    seconds = remaining(environment, time.time())
    environment = {**environment, 'TRINKET_DIAGNOSTICS_SESSION_ID': environment.get('TRINKET_DIAGNOSTICS_SESSION_ID') or 'ci-budget-' + uuid.uuid4().hex}
    results = Path(environment.get('RESULTS_DIR', '.DerivedData/TestResults')).resolve()
    if seconds is not None and seconds <= 0:
        timeout_report(command, results, environment, phase=phase)
        return 124
    # Give xcode-runner time to produce its ordinary completion manifest first.
    env = dict(environment)
    if seconds is not None:
        env['TRINKET_XCODE_WALL_TIMEOUT_SECONDS'] = str(max(1, int(seconds - 30)))
    requested = environment.get('TRINKET_XCODE_WALL_TIMEOUT_SECONDS')
    if seconds is not None and requested and requested.isdigit() and int(requested) > 0:
        env['TRINKET_XCODE_WALL_TIMEOUT_SECONDS'] = str(min(int(requested), int(env['TRINKET_XCODE_WALL_TIMEOUT_SECONDS'])))
    before = {path: path.stat().st_mtime_ns for path in results.glob('*-invocation.json')}
    started = time.monotonic()
    transcript = tempfile.TemporaryFile()
    try:
        process = subprocess.Popen(command, env=env, start_new_session=True,
                                   stdout=transcript, stderr=subprocess.STDOUT)
    except OSError as error:
        transcript.close()
        preparation_report(command, results, env, 127, time.monotonic() - started, str(error), phase)
        return 127
    offset = 0

    def forward_output() -> None:
        nonlocal offset
        # pread leaves the child's shared write position intact.
        end = os.fstat(transcript.fileno()).st_size
        while offset < end:
            data = os.pread(transcript.fileno(), min(65536, end - offset), offset)
            if not data:
                break
            offset += len(data)
            sys.stdout.write(data.decode('utf-8', errors='replace'))
        sys.stdout.flush()

    def output_tail() -> str:
        size = os.fstat(transcript.fileno()).st_size
        return os.pread(transcript.fileno(), min(size, 65536), max(0, size - 65536)).decode('utf-8', errors='replace')

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
        while True:
            forward_output()
            available = remaining(environment, time.time())
            try:
                status = process.wait(timeout=min(0.25, available) if available is not None else 0.25)
                break
            except subprocess.TimeoutExpired:
                if available is not None and remaining(environment, time.time()) <= 0:
                    terminate()
                    forward_output()
                    timeout_report(command, results, environment, time.monotonic() - started, output_tail(), phase)
                    return 124
        forward_output()
        if status and not has_failure_receipt(results, env, before):
            preparation_report(command, results, env, status, time.monotonic() - started, output_tail(), phase)
        return status
    finally:
        transcript.close()
        for signum, handler in previous.items():
            signal.signal(signum, handler)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', default='command-preparation')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('A command is required')
    raise SystemExit(run(command, dict(os.environ), args.phase))


if __name__ == '__main__':
    main()
