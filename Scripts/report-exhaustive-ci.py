#!/usr/bin/env python3
"""Report actual advisory UI job conclusions from paginated GitHub job results."""

from __future__ import annotations

import json
import argparse
import os
from pathlib import Path


def job_outcome(job: dict) -> str:
    if job.get('status') != 'completed':
        return f"{job.get('status') or 'unknown'} (not completed)"
    steps = {step.get('name'): step.get('conclusion') for step in job.get('steps', [])}
    if (job.get('conclusion') == 'success' and steps.get('Record assessed exhaustive coverage') == 'success'
            and steps.get('Record completed exhaustive execution') != 'success'):
        return 'partial / unavailable'
    return job.get('conclusion') or 'unknown'


def report(pages: list[dict], allow_unavailable=False) -> tuple[str, list[str]]:
    if not isinstance(pages, list) or any(not isinstance(page, dict) or not isinstance(page.get('jobs'), list)
                                          or any(not isinstance(job, dict) or not isinstance(job.get('name'), str)
                                                 for job in page['jobs']) for page in pages):
        raise ValueError('Missing or unreadable job records')
    jobs = [job for page in pages for job in page['jobs'] if 'Exhaustive UI (' in job['name']]
    warnings = []
    if not jobs:
        warnings.append('No exhaustive UI shards found; advisory status is unknown.')
    for job in jobs:
        outcome = job_outcome(job)
        if outcome not in ('success', 'skipped') and not (allow_unavailable and outcome == 'partial / unavailable'):
            warnings.append(f"Advisory exhaustive shard: {job['name']} — {outcome}")
    skipped = sum(job.get('status') == 'completed' and job.get('conclusion') == 'skipped' for job in jobs)
    partial = sum(job_outcome(job) == 'partial / unavailable' for job in jobs)
    title = 'attention required' if warnings else 'partial / unavailable' if partial else (
        'not run' if skipped == len(jobs) else 'incomplete' if skipped else 'passed'
    )
    lines = [f'### Exhaustive UI: {title} (advisory)', '',
             '| Shard | Result |', '|---|---|']
    for job in jobs:
        outcome = job_outcome(job)
        name = job['name'].replace('|', '\\|').replace('\n', ' ')
        lines.append(f"| [{name}]({job['html_url']}) | {outcome} |")
    lines += ['', *warnings]
    if skipped:
        lines.append(f'{skipped} skipped shard(s) provide no execution evidence.')
    if partial:
        lines.append(f'{partial} shard(s) have coverage gaps; CICoverage receipts identify what did and did not execute.')
    lines += ['', 'Exhaustive UI remains advisory; these results do not block CI OK.', '']
    return '\n'.join(lines), warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('jobs', type=Path, help='Paginated GitHub jobs from gh api --paginate --slurp')
    parser.add_argument('--require-execution', action='store_true',
                        help='fail the advisory aggregate when requested UI is failed, skipped, or unavailable')
    parser.add_argument('--allow-unavailable', action='store_true',
                        help='accept reported capability gaps while keeping real test failures fatal')
    args = parser.parse_args()
    try:
        summary, warnings = report(json.loads(args.jobs.read_text()), args.allow_unavailable)
    except (OSError, ValueError, KeyError, TypeError) as error:
        summary = '### Exhaustive UI: status unknown (job results could not be read)\n'
        warnings = [f'Could not read exhaustive shard results: {error}']
    print(summary)
    for warning in warnings:
        escaped = warning.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        print(f'::warning::{escaped}')
    if path := os.environ.get('GITHUB_STEP_SUMMARY'):
        with Path(path).open('a') as stream:
            stream.write(summary)
    if args.require_execution and (warnings or '| skipped |' in summary):
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
