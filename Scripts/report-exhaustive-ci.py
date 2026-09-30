#!/usr/bin/env python3
"""Report actual advisory UI job conclusions from paginated GitHub job results."""

from __future__ import annotations

import json
import argparse
import os
from pathlib import Path


def report(pages: list[dict]) -> tuple[str, list[str]]:
    jobs = [job for page in pages for job in page['jobs'] if 'Exhaustive UI (' in job['name']]
    warnings = []
    if not jobs:
        warnings.append('No exhaustive UI shards found; advisory status is unknown.')
    for job in jobs:
        outcome = job.get('conclusion') or job['status']
        if outcome not in ('success', 'skipped'):
            warnings.append(f"Advisory exhaustive shard: {job['name']} — {outcome}")
    title = 'attention required' if warnings else (
        'not run' if all(job.get('conclusion') == 'skipped' for job in jobs) else 'passed'
    )
    lines = [f'### Exhaustive UI: {title} (advisory)', '',
             '| Shard | Result |', '|---|---|']
    for job in jobs:
        outcome = job.get('conclusion') or job['status']
        name = job['name'].replace('|', '\\|').replace('\n', ' ')
        lines.append(f"| [{name}]({job['html_url']}) | {outcome} |")
    lines += ['', *warnings, '', 'Exhaustive UI remains advisory; these results do not block CI OK.', '']
    return '\n'.join(lines), warnings


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('jobs', type=Path, help='Paginated GitHub jobs from gh api --paginate --slurp')
    args = parser.parse_args()
    try:
        summary, warnings = report(json.loads(args.jobs.read_text()))
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


if __name__ == '__main__':
    main()
