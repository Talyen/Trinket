#!/usr/bin/env python3
"""Plan, validate/apply, or check agent-authored localization deltas without an AI service."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from internal.localization import apply, check, load, plan, response_template


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    commands = parser.add_subparsers(dest='operation', required=True)
    commands.add_parser('plan', help='Write the current translation queue as JSON to stdout')
    commands.add_parser('template', help='Write a response skeleton with queue metadata and empty translation/review fields')
    update = commands.add_parser('apply', help='Validate an entire response before replacing catalogs and receipts')
    update.add_argument('response', type=Path)
    commands.add_parser('check', help='Read-only freshness, coverage, and resource validation')
    args = parser.parse_args(argv)
    try:
        if args.operation == 'plan':
            print(json.dumps(plan(args.root), ensure_ascii=False, indent=2))
        elif args.operation == 'template':
            print(json.dumps(response_template(args.root), ensure_ascii=False, indent=2))
        elif args.operation == 'apply':
            apply(args.root, load(args.response))
        else:
            errors = check(args.root)
            if errors:
                print('\n'.join(errors), file=sys.stderr)
                print('Run python3 Scripts/localization.py plan; translate/review its queue, then apply the response.', file=sys.stderr)
                return 1
            print('Localization PASS: all configured locales are current and reviewed; resources are consistent.')
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f'Localization failed: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
