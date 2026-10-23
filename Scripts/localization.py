#!/usr/bin/env python3
"""Coordinate local AI translation/review or manually prepare, apply, and check localization."""
from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
from pathlib import Path
import sys

from internal.localization import apply, check, load, plan, prepare, record_review, response_template


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    commands = parser.add_subparsers(dest='operation', required=True)
    commands.add_parser('plan', help='Write the current translation queue as JSON to stdout')
    commands.add_parser('template', help='Write a response skeleton with queue metadata and empty translation/review fields')
    preparation = commands.add_parser('prepare', aliases=['job'], help='Save a fresh queue, resuming matching work from the latest draft')
    preparation.add_argument('--resume', type=Path, help='Resume this response instead of the latest draft; originals remain untouched')
    automated = commands.add_parser('run', help='Translate, independently review, and apply with separate local Codex sessions')
    automated.add_argument('--resume', type=Path)
    automated.add_argument('--codex', default='codex', help='Codex CLI executable; uses its configured model and authentication')
    automated.add_argument('--timeout', type=int, default=1800, help='Maximum seconds per AI pass')
    review = commands.add_parser('review', help='Record your completed separate review of pending translations; preserve matching completed reviews; does not perform AI review')
    review.add_argument('response', type=Path)
    review.add_argument('--rationale', required=True, help='What you checked in the completed separate review of each pending entry')
    finish = commands.add_parser('finish', help='After separate AI review, record your attestation and apply the response with validation')
    finish.add_argument('response', type=Path)
    finish.add_argument('--rationale', required=True, help='What the completed separate AI review checked; this command does not perform review')
    update = commands.add_parser('apply', help='Validate an entire response before replacing catalogs and receipts')
    update.add_argument('response', type=Path)
    validation = commands.add_parser('check', help='Read-only freshness, coverage, and resource validation')
    validation.add_argument('--paths', nargs='+', help='Check affected sources/catalogs and their consumers; omit for the full repository')
    args = parser.parse_args(argv)
    try:
        if args.operation == 'run':
            from internal.localization_runner import run
            if args.timeout <= 0:
                raise ValueError('--timeout must be positive')
            return run(args.root.resolve(), args.resume, codex=args.codex, timeout=args.timeout)
        if args.operation == 'plan':
            print(json.dumps(plan(args.root), ensure_ascii=False, indent=2))
        elif args.operation == 'template':
            print(json.dumps(response_template(args.root), ensure_ascii=False, indent=2))
        elif args.operation in {'prepare', 'job'}:
            directory = prepare(args.root, args.resume)
            print(f'Queue: {directory / "plan.json"}')
            print(f'Translate and separately review: {directory / "response.json"}')
            queue = load(directory / 'plan.json')
            print(f"Pending: {len(queue['requests'])} translations across {len({item['locale'] for item in queue['requests']})} locales.")
            if not queue['requests']:
                print('Localization job complete: no queued translations or reviews.')
                return 0
            finish_command = shlex.join(['python3', 'Scripts/localization.py', '--root', str(args.root),
                                         'finish', str(directory / 'response.json'), '--rationale',
                                         '<what the completed separate review checked>'])
            (directory / 'translate.md').write_text(
                '# Translation task\n\n'
                f'Fill pending translations in `{directory / "response.json"}`. The response includes English, '
                'game context, glossary, previous values, placeholders and native plural forms. '
                'Preserve source IDs, hashes, semantic tags and every configured locale. '
                'Leave review records pending. Do not copy English to clear the queue.\n\n'
                'After translation, give review.md to a separate high-reasoning AI reviewer. '
                'Do not run finish until that review has actually completed.\n')
            (directory / 'review.md').write_text(
                '# Independent localization review\n\n'
                f'Review every pending entry in `{directory / "response.json"}` against its English '
                'and game context. Check meaning, actors, targets, conditions, timing, quantities, chance, '
                'terminology, grammar, placeholders, semantic markup and all native plural forms. '
                'Correct defects and inspect the corrected values. Do not reuse the translation pass as review. '
                'Preserve matching completed reviews and do not attest entries you have not checked.\n\n'
                'Only after completing this separate review, record an honest rationale and finish:\n\n'
                f'```sh\n{finish_command}\n```\n\n'
                'finish binds review to the translated values, applies resources and validates the inventory. '
                'The command performs no AI review itself. A remaining queue means the job is incomplete.\n')
            print(f'Translation task: {directory / "translate.md"}')
            print(f'Independent review task: {directory / "review.md"}')
            print('After translating and completing a separate AI review, finish with:')
            print(finish_command)
        elif args.operation == 'review':
            record_review(args.root, args.response, args.rationale)
            print(f'Recorded the caller-attested review: {args.response}')
        elif args.operation in {'apply', 'finish'}:
            if args.operation == 'finish':
                record_review(args.root, args.response, args.rationale)
            apply(args.root, load(args.response))
            errors = check(args.root)
            if errors:
                print('\n'.join(errors), file=sys.stderr)
                print('Reviewed entries were applied; localization remains incomplete. Resume with localization.py prepare.', file=sys.stderr)
                return 1
            print('Localization PASS: applied resources and all configured locales are current and reviewed.')
        else:
            paths = None if os.environ.get('GITHUB_ACTIONS') == 'true' else args.paths
            errors = check(args.root, paths)
            if errors:
                print('\n'.join(errors), file=sys.stderr)
                print('Run python3 Scripts/localization.py prepare; translate/review its queue, then apply the response.', file=sys.stderr)
                return 1
            print('Localization PASS: affected sources, catalogs and consumers are consistent; full coverage remains CI-owned.'
                  if paths else 'Localization PASS: all configured locales are current and reviewed; resources are consistent.')
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f'Localization failed: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
