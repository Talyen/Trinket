#!/usr/bin/env python3
"""Execute available CI coverage without converting infrastructure gaps into passes."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import uuid

from internal.cli import load_sibling
from internal.ci_capabilities import record_coverage, unavailable_failure

BUDGET = load_sibling('capability_budget', 'ci-run-budget.py')


def run(command, scope, environment, requires_simulator=False):
    environment = {**environment, 'TRINKET_DIAGNOSTICS_SESSION_ID':
                   environment.get('TRINKET_DIAGNOSTICS_SESSION_ID') or 'capability-' + uuid.uuid4().hex}
    results = Path(environment.get('RESULTS_DIR', '.DerivedData/TestResults')).resolve()
    derived = Path(environment.get('DERIVED_DATA_PATH', '.DerivedData')).resolve()
    before = {path: path.stat().st_mtime_ns for root in (results, derived) for path in root.rglob('*-invocation.json')}
    coverage_root = Path(environment.get('DERIVED_DATA_PATH', '.DerivedData')) / 'CICoverage'
    prior_coverage = set(coverage_root.glob('*.json'))
    unavailable = requires_simulator and environment.get('TRINKET_CI_SIMULATOR_AVAILABLE') == 'false'
    status = 78 if unavailable else BUDGET.run(command, environment)
    gap = ('No installed working simulator was prepared.' if unavailable else
           unavailable_failure(results, before, (derived,)) if status else None)
    child_gaps = [json.loads(path.read_text()) for path in coverage_root.glob('*.json') if path not in prior_coverage]
    partial = any(item.get('status') in ('unavailable', 'partial') for item in child_gaps)
    outcome = 'unavailable' if gap else 'failed' if status else 'partial' if partial else 'passed'
    record_coverage(scope, outcome, gap or '', environment=environment, details={'command': command, 'exit_code': status})
    if output := environment.get('GITHUB_OUTPUT'):
        with Path(output).open('a') as stream:
            stream.write(f'executed={str(outcome == "passed").lower()}\nready={str(status == 0).lower()}\ncoverage-status={outcome}\n')
    return 0 if gap else status


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', required=True)
    parser.add_argument('--requires-simulator', action='store_true')
    parser.add_argument('--unavailable', help='Record a known missing capability without executing tests')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.unavailable:
        record_coverage(args.scope, 'unavailable', args.unavailable)
        raise SystemExit(0)
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('A verification command is required')
    raise SystemExit(run(command, args.scope, dict(os.environ), args.requires_simulator))
