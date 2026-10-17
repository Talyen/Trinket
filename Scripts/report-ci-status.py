#!/usr/bin/env python3
"""Keep required, advisory, cancelled and unrequested job outcomes distinct."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


def report(jobs: dict, title: str, required: list[str]) -> tuple[str, bool]:
    if not jobs or not isinstance(jobs, dict) or any(
            not isinstance(job, dict) or job.get('result') not in ('success', 'failure', 'cancelled', 'skipped')
            for job in jobs.values()):
        raise ValueError('Missing or unreadable job conclusions')
    missing = [name for name in required if jobs.get(name, {}).get('result') != 'success']
    failed = [name for name, job in jobs.items() if job['result'] == 'failure']
    cancelled = [name for name, job in jobs.items() if job['result'] == 'cancelled']
    unavailable = [name for name in missing if jobs.get(name, {}).get('result') != 'cancelled']
    outcome = 'failed' if failed or unavailable else 'cancelled' if cancelled else 'passed'
    lines = [f'### {title}: {outcome}', '', '| Job | Result |', '|---|---|']
    for name, job in jobs.items():
        name = name.replace('|', '\\|').replace('\n', ' ')
        lines.append(f"| {name} | {job['result']} |")
    lines += ['', f"Failed jobs: {len(failed)}. Cancelled jobs: {len(cancelled)}.",
              'Skipped jobs provide no execution evidence.']
    if missing:
        lines.append('Requested execution missing: ' + ', '.join(missing))
    return '\n'.join(lines) + '\n', bool(failed or cancelled or missing)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--title', required=True)
    parser.add_argument('--require', nargs='*', default=[])
    args = parser.parse_args()
    try:
        summary, failed = report(json.loads(os.environ['JOB_RESULTS']), args.title, args.require)
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        summary, failed = f'### {args.title}: unknown\n\n{error}\n', True
    print(summary)
    if path := os.environ.get('GITHUB_STEP_SUMMARY'):
        with Path(path).open('a') as stream:
            stream.write(summary)
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
