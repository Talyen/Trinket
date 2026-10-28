#!/usr/bin/env python3
"""Report Trinket storage and guarded cleanup candidates without changing files."""
from collections import Counter
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

from internal.cli import ROOT, primary_worktree_root


def command(args, *, timeout=90):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as error:
        return None, str(error)
    return result, result.stderr.strip()


def allocated(path):
    if not path.exists() or path.is_symlink():
        return None
    result, _ = command(['du', '-sk', str(path)])
    if result is None or result.returncode:
        return None
    try:
        return int(result.stdout.split()[0]) * 1024
    except (ValueError, IndexError):
        return None


def size(value):
    return 'unavailable' if value is None else f'{value / 1024**3:.2f} GiB'


def worktree_inventory(root):
    result, error = command(['git', '-C', str(root), 'worktree', 'list', '--porcelain', '-z'], timeout=10)
    if result is None or result.returncode:
        print(f'Worktree inventory unavailable: {error}')
        return
    records = result.stdout.rstrip('\0').split('\0\0')
    for record in records[1:]:
        fields = record.split('\0')
        path = next((item[9:] for item in fields if item.startswith('worktree ')), '')
        head = next((item[5:] for item in fields if item.startswith('HEAD ')), '')
        if not path or not head:
            print('  unknown worktree registration; preserve')
            continue
        ancestor, _ = command(['git', '-C', str(root), 'merge-base', '--is-ancestor', head, 'main'], timeout=10)
        status, _ = command(['git', '-C', path, 'status', '--porcelain', '--untracked-files=normal'], timeout=10)
        relation = 'ancestor of main' if ancestor is not None and ancestor.returncode == 0 else (
            'not an ancestor' if ancestor is not None and ancestor.returncode == 1 else 'ancestry unknown')
        state = 'status unknown' if status is None or status.returncode else ('dirty' if status.stdout else 'clean tracked and untracked files')
        locked = ', locked' if any(item.startswith('locked') for item in fields) else ''
        print(f'  {path}: {relation}, {state}{locked}; activity and ignored files not assessed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--details', action='store_true', help='show every guarded cleanup decision')
    parser.add_argument('--evidence-details', action='store_true', help='show preserved evidence size by task')
    args = parser.parse_args()
    root = primary_worktree_root(ROOT)
    git, error = command(['git', '-C', str(root), 'rev-parse', '--path-format=absolute', '--git-common-dir'], timeout=10)
    if git is None or git.returncode:
        parser.exit(2, f'Git directory unavailable: {error}\n')
    common = Path(git.stdout.strip())
    groups = [('worktrees', root / '.worktrees'), ('evidence', common / 'trinket-evidence'),
              ('Git objects', common / 'objects'), ('derived data', root / '.DerivedData'),
              ('TestFlight working data', root / '.DerivedData/testflight'), ('tools', root / '.tools')]
    print(f'Primary checkout: {root}')
    print(f'Volume free: {size(shutil.disk_usage(root).free)}')
    for name, path in groups:
        print(f'{name}: {size(allocated(path))} ({path})')
    print('Sizes may overlap, include shared APFS blocks, and do not predict free space recovered.')
    if args.evidence_details:
        evidence = common / 'trinket-evidence/codex'
        if evidence.is_dir() and not evidence.is_symlink():
            branches = [path for path in evidence.iterdir() if path.is_dir() and not path.is_symlink()]
            result, error = command(['du', '-sk', *(str(path) for path in branches)]) if branches else (None, '')
            print('\nEvidence by task:')
            if result is None or result.returncode:
                print(f'  Inventory unavailable: {error or "no evidence"}')
            else:
                for line in result.stdout.splitlines():
                    amount, _, path = line.partition('\t')
                    try:
                        print(f'  {Path(path).name}: {size(int(amount) * 1024)}')
                    except ValueError:
                        print(f'  Unreadable size: {line}')
    print('\nWorktrees:')
    worktree_inventory(root)
    print('\nGuarded cleanup inventory:')
    result, error = command([sys.executable, str(ROOT / 'Scripts/cleanup-outputs.py'),
                             '--dry-run', '--resources', '--primary'], timeout=180)
    if result is None or result.returncode:
        print(f'Cleanup inventory incomplete: {error or "command failed"}')
        return 1
    lines = result.stdout.splitlines()
    if args.details:
        print(result.stdout, end='')
    else:
        reasons = Counter(line.split(': ', 1)[1].split('; allocatedBytes=', 1)[0]
                          for line in lines if line.startswith('SKIP ') and ': ' in line)
        for line in lines:
            if line.startswith(('Eligible:', 'Eligible release duplicates:', 'WOULD ', 'REVIEW ')):
                print(line)
        for reason, count in reasons.most_common():
            print(f'  {count} protected: {reason}')
        print('Use --details for individual paths and reasons.')
    print('Dry run only. Clean status or ancestry alone does not establish an inactive worktree.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
