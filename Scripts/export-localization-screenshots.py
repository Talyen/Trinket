#!/usr/bin/env python3
"""Export CI localization attachments for the development agent's visual review."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def suite_identifier(summary) -> str | None:
    pending = [summary]
    while pending:
        item = pending.pop()
        if isinstance(item, list):
            pending.extend(item)
        elif isinstance(item, dict):
            if str(item.get('name', '')).split('.')[-1] == 'LocalizationUITests':
                return item.get('nodeIdentifier') or item.get('nodeIdentifierURL') or 'LocalizationUITests'
            pending.extend(value for value in item.values() if isinstance(value, (dict, list)))
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('results', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for result in sorted(args.results.rglob('*.xcresult')):
        summary = subprocess.run(['xcrun', 'xcresulttool', 'get', 'test-results', 'tests', '--path', str(result)],
                                 check=True, capture_output=True, text=True, timeout=30)
        identifier = suite_identifier(json.loads(summary.stdout))
        if identifier is None:
            continue
        suffix = hashlib.sha256(str(result.relative_to(args.results)).encode()).hexdigest()[:8]
        subprocess.run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(result),
                        '--output-path', str(args.output / f'{result.stem}-{suffix}'), '--test-id', identifier],
                       check=True, timeout=60)


if __name__ == '__main__':
    main()
