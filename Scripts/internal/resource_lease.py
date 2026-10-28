"""Encode and validate producer-owned output scopes for retention leases."""
from __future__ import annotations

import base64
import json
import os
from pathlib import Path
import subprocess

from internal.cli import worktree_roots

PREFIX = 'scope-v1:'


def stable_alias(path: Path) -> bool:
    """A user-replaceable symlink may be retargeted after the final check."""
    if not path.exists():
        return False
    for part in (path, *path.parents):
        if part.is_symlink():
            parent = part.parent
            if parent.stat().st_uid == os.getuid() or os.access(parent, os.W_OK):
                return False
    return True


def make_scope(pid: int, root: Path, paths: list[str]) -> str:
    if type(pid) is not int or pid <= 0:
        raise ValueError('Invalid lease owner')
    root = root.resolve()
    if not root.is_absolute() or root == Path('/') or root not in worktree_roots(root):
        raise ValueError('Lease checkout is not a registered worktree')
    started = ' '.join(subprocess.check_output(['ps', '-p', str(pid), '-o', 'lstart='], text=True, timeout=5).split())
    if not started:
        raise ValueError('Lease owner identity unavailable')
    scopes = {(str(root), str(root))}
    for value in [str(root / '.DerivedData'), *paths]:
        if not value:
            continue
        path = Path(value)
        if not path.is_absolute():
            path = root / path
        path = Path(os.path.abspath(path))
        resolved = path.resolve()
        if resolved == Path('/'):
            raise ValueError('Unbounded lease path')
        scopes.add((str(path), str(resolved)))
    data = {'version': 1, 'pid': pid, 'started': started, 'checkout': str(root),
            'paths': [list(pair) for pair in sorted(scopes)]}
    return PREFIX + base64.urlsafe_b64encode(json.dumps(data, separators=(',', ':')).encode()).decode()


def scope_for(slot: Path, pid: int, processes: dict, root: Path) -> list[Path] | None:
    """A missing, legacy, malformed, reused or uninspectable lease remains global."""
    try:
        fields = slot.read_text().split()
        tokens = [field for field in fields if field.startswith(PREFIX)]
        if len(tokens) != 1:
            return None
        payload = json.loads(base64.b64decode(tokens[0][len(PREFIX):], altchars=b'-_', validate=True))
        if pid in processes:
            started = processes[pid][0]
        else:
            # Inspect only the exact owner PID recorded in this lease.
            started = ' '.join(subprocess.check_output(['ps', '-p', str(pid), '-o', 'lstart='],
                                                       text=True, timeout=5).split())
        if (not started or payload['version'] != 1 or payload['pid'] != pid or payload['started'] != started
                or not isinstance(payload['paths'], list) or not payload['paths']):
            return None
        checkout = Path(payload['checkout'])
        if not checkout.is_absolute() or checkout != checkout.resolve() or checkout not in worktree_roots(root):
            return None
        scopes = []
        originals = set()
        for entry in payload['paths']:
            if not isinstance(entry, list) or len(entry) != 2 or not all(isinstance(name, str) for name in entry):
                return None
            original, path = map(Path, entry)
            if (not original.is_absolute() or not path.is_absolute() or path == Path('/')
                    or not stable_alias(original) or original.resolve() != path or path != path.resolve()):
                return None
            originals.add(original)
            scopes.append(path)
        if checkout not in scopes or checkout / '.DerivedData' not in originals:
            return None
        return scopes
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        return None


def overlaps(path: Path, scopes: list[Path]) -> bool:
    return any(path == scope or path.is_relative_to(scope) or scope.is_relative_to(path) for scope in scopes)
