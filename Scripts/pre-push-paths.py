#!/usr/bin/env python3
"""Select outgoing paths only when local checks can inspect the outgoing source."""

from __future__ import annotations

import re
import subprocess
import sys


def git(*args: str) -> str:
    result = subprocess.run(
        ['git', '-c', 'core.fsmonitor=false', '-c', 'core.untrackedCache=false', *args],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        raise ValueError(f'Could not inspect push revisions: {result.stderr.strip()}')
    return result.stdout


def pushed_paths(lines: str) -> list[str]:
    head = git('rev-parse', 'HEAD').strip()
    updates = [line.split() for line in lines.splitlines() if line.strip()]
    if not updates:
        return []
    paths: set[str] = set()
    has_source = False
    for fields in updates:
        if len(fields) != 4 or any(not re.fullmatch(r'(?:[a-f0-9]{40}|[a-f0-9]{64})', oid)
                                   for oid in (fields[1], fields[3])):
            raise ValueError('Invalid pre-push input; expected Git ref and object ID pairs.')
        local_ref, local_oid, _, remote_oid = fields
        if set(local_oid) == {'0'}:
            continue
        has_source = True
        commit = git('rev-parse', f'{local_oid}^{{commit}}').strip()
        if commit != head:
            raise ValueError(f'Check out {local_ref} before pushing it; checks must inspect the outgoing source.')
        # A new remote ref has no verified base: inspect its entire tree.
        output = (git('ls-tree', '-r', '--name-only', '-z', commit)
                  if set(remote_oid) == {'0'} else
                  git('diff', '--no-renames', '--name-only', '-z', remote_oid, commit, '--'))
        paths.update(path for path in output.split('\0') if path)
    if has_source and git('status', '--porcelain', '--untracked-files=all', '-z'):
        raise ValueError('Pre-push requires a clean checkout so checks inspect committed source. Preserve and commit outstanding work before pushing.')
    if any('\n' in path or '\r' in path for path in paths):
        raise ValueError('Pre-push path routing requires single-line filenames.')
    return sorted(paths)


if __name__ == '__main__':
    try:
        selected = pushed_paths(sys.stdin.read())
    except (ValueError, OSError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from None
    if selected:
        print('\n'.join(selected))
