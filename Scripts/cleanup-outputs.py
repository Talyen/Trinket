#!/usr/bin/env python3
"""Expire disposable output after 24 hours and idle run caches after three days; preserve active and release state."""

import argparse
import os
import subprocess
from pathlib import Path

from internal.cli import ROOT, primary_worktree_root
from internal import output_retention as retention


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--dry-run', action='store_true')
    mode.add_argument('--apply', action='store_true')
    mode.add_argument('--keep', type=Path, help='keep a known output until --release')
    mode.add_argument('--release', type=Path, help='restore normal expiry for an output')
    mode.add_argument('--begin', type=Path, help=argparse.SUPPRESS)
    mode.add_argument('--finish', type=Path, help=argparse.SUPPRESS)
    parser.add_argument('--owner-pid', type=int, default=os.getppid(), help=argparse.SUPPRESS)
    parser.add_argument('--status', type=int, default=0, help=argparse.SUPPRESS)
    parser.add_argument('--comparison', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument('--experiments', action='store_true', help='also remove the three known abandoned experiment builds')
    parser.add_argument('--resources', action='store_true', help='also verify and expire completed release duplicates (may hash large artifacts)')
    parser.add_argument('--release-duplicates-only', action='store_true', help='verify at most one backed-up ready release; preserve receipts and authoritative artifacts')
    parser.add_argument('--intermediates-only', action='store_true', help='expire only idle compiler scratch, preserving all evidence and products')
    parser.add_argument('--receipt', type=Path, help='write a compact cleanup/dry-run receipt')
    parser.add_argument('--primary', action='store_true', help='inspect/clean the primary checkout rather than this task checkout')
    args = parser.parse_args()
    try:
        root = primary_worktree_root(ROOT) if args.primary else ROOT
        path = args.keep or args.release or args.begin or args.finish
        if path is not None:
            if '..' in path.parts:
                raise ValueError('parent traversal is not allowed')
            path = Path(os.path.abspath(path))
            if not retention.managed_path(path, root):
                if args.begin:
                    parser.exit(3)
                raise ValueError('control requires a known repository output path')
            if not path.exists():
                raise ValueError('control requires an existing output path')
            path = path.resolve()
            if retention.marker(path, retention.KEEP).is_symlink() or retention.marker(path, retention.OWNER).is_symlink():
                raise ValueError('retention controls must not be symlinks')
            if args.keep:
                retention.marker(path, retention.KEEP).touch()
                print(f'Keeping {path} until --release')
            elif args.release:
                retention.marker(path, retention.KEEP).unlink(missing_ok=True)
                print(f'Released {path}; normal expiry applies')
            elif args.begin:
                retention.begin(path, root, args.owner_pid)
            else:
                retention.finish(path, root, args.owner_pid, args.status, comparison=args.comparison)
        else:
            if args.release_duplicates_only:
                from internal import release_retention
                decisions = []
                if args.receipt:
                    retention.prepare_cleanup_receipt(args.receipt, root)
                release_retention.cleanup(root, apply=args.apply, max_verify=1, decisions=decisions)
                if args.receipt:
                    from internal.cli import write_json_atomic
                    write_json_atomic(args.receipt, {'schema': 1, 'dry_run': not args.apply,
                                      'policy': 'one-verified-release-duplicate', 'decisions': decisions})
                return
            retention.cleanup(root, apply=args.apply, experiments=args.experiments,
                              intermediates_only=args.intermediates_only, receipt=args.receipt)
            if args.resources and not args.intermediates_only:
                from internal import release_retention
                release_retention.cleanup(root, apply=args.apply)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f'Output cleanup refused: {error}\n')


if __name__ == '__main__':
    main()
