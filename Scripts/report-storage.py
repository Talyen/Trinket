#!/usr/bin/env python3
"""Report Trinket storage and guarded cleanup candidates without changing files."""
from collections import Counter
import argparse
from datetime import datetime
import json
import re
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


def checkout_state(root, path, branch, head, *, details=False, common=None):
    if not branch.startswith('refs/heads/codex/') or '..' in Path(branch).parts:
        return 'completion intent unknown'
    name = branch.removeprefix('refs/heads/')
    common = common or root / '.git'
    record = common / 'trinket-evidence' / name / 'checkout-state.json'
    try:
        if record.is_symlink() or any(p.is_symlink() for p in record.parents if p.is_relative_to(common)):
            return 'completion intent unknown'
        data = json.loads(record.read_text())
        if (data['schema'] != 1 or data['branch'] != name or data['head'] != head
                or data['checkout'] != path or data['state'] not in ('retained', 'cleanup-pending')):
            return 'completion intent unknown'
        reason = data.get('reason')
        if not isinstance(reason, str) or not reason.strip() or len(reason) > 240:
            return 'completion intent unknown'
        state = 'intentionally retained' if data['state'] == 'retained' else 'final cleanup pending'
        return f'{state} ({reason})' if details else state
    except (OSError, ValueError, KeyError, TypeError):
        return 'completion intent unknown'


def worktree_inventory(root, common=None):
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
        # A read-only inventory should not start a persistent monitor in each checkout.
        status, _ = command(['git', '-c', 'core.fsmonitor=false', '-C', path,
                             'status', '--porcelain', '--untracked-files=normal'], timeout=10)
        relation = 'ancestor of main' if ancestor is not None and ancestor.returncode == 0 else (
            'not an ancestor' if ancestor is not None and ancestor.returncode == 1 else 'ancestry unknown')
        state = 'status unknown' if status is None or status.returncode else ('dirty' if status.stdout else 'clean tracked and untracked files')
        locked = ', locked' if any(item.startswith('locked') for item in fields) else ''
        branch = next((item[7:] for item in fields if item.startswith('branch refs/heads/')), '')
        intent = checkout_state(root, path, branch, head, details=True, common=common)
        print(f'  {path}: {relation}, {state}{locked}; {intent}; activity and ignored files not assessed')


def worktree_intents(root, common=None):
    result, error = command(['git', '-C', str(root), 'worktree', 'list', '--porcelain', '-z'], timeout=10)
    if result is None or result.returncode:
        print(f'Worktree intent unavailable: {error}')
        return
    counts = Counter()
    for record in result.stdout.rstrip('\0').split('\0\0')[1:]:
        fields = record.split('\0')
        path = next((x[9:] for x in fields if x.startswith('worktree ')), '')
        head = next((x[5:] for x in fields if x.startswith('HEAD ')), '')
        branch = next((x[7:] for x in fields if x.startswith('branch refs/heads/')), '')
        counts[checkout_state(root, path, branch, head, common=common)] += 1
    print('Worktree intent: ' + ', '.join(f'{n} {state}' for state, n in sorted(counts.items()))
          + '; activity is not assessed.')


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
    worktree_intents(root, common)
    if args.details:
        print('\nWorktrees:')
        worktree_inventory(root, common)
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
        dates = []
        for reason in reasons:
            match = re.search(r'Duplicate grace period ends at ([0-9]+)', reason)
            if match:
                dates.append(int(match.group(1)))
        candidates = [line for line in lines if line.startswith(('WOULD ', 'REVIEW '))]
        for line in lines:
            if line.startswith(('Eligible:', 'Eligible release duplicates:')):
                print(line)
        for line in candidates[:3]:
            print(line)
        if len(candidates) > 3:
            print(f'  {len(candidates) - 3} more decisions; use --details.')
        if dates:
            print('Next release review: ' + datetime.fromtimestamp(min(dates)).astimezone().strftime('%Y-%m-%d %H:%M %Z'))
        print(f'Protected decisions: {sum(reasons.values())}')
        for reason, count in reasons.most_common(3):
            if not reason.startswith('Duplicate grace period ends at '):
                print(f'  {count}: {reason}')
        print('Use --details for all paths and reasons.')
    caches, cache_error = command([sys.executable, str(ROOT / 'Scripts/cleanup-outputs.py'),
                                   '--dry-run', '--intermediates-only', '--products', '--worktrees'], timeout=180)
    if caches is None or caches.returncode:
        print(f'Worktree cache inventory incomplete: {cache_error or "command failed"}')
        return 1
    if args.details:
        print(caches.stdout, end='')
    else:
        cache_lines = caches.stdout.splitlines()
        for line in cache_lines:
            if line.startswith('Eligible worktree cache roots:'):
                print(line)
        skipped = [line for line in cache_lines if line.startswith('SKIP ')]
        if skipped:
            print(f'Protected worktree cache roots: {len(skipped)}; use --details for reasons.')
    print('Dry run only. Clean status or ancestry alone does not establish an inactive worktree.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
