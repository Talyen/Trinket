"""Register managed build consumers against the shared retention lifecycle lock."""
from contextlib import contextmanager
import os
from pathlib import Path
import subprocess
import time
import uuid

from internal.cli import primary_worktree_root
from internal.output_retention import safe_path


@contextmanager
def shared_build_lease(root: Path, *, paths: tuple[Path, ...] = ()):
    primary = primary_worktree_root(root)
    derived = primary / '.DerivedData'
    lock = derived / '.active-sim/.sim-lifecycle.lock'
    state = derived / '.active-build'
    if not safe_path(lock, primary) or not safe_path(state, primary):
        raise ValueError('Unsafe shared build lease path')
    lock.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + 10
    while True:
        try:
            lock.mkdir()
            break
        except FileExistsError:
            if time.monotonic() >= deadline:
                raise RuntimeError('Shared build lifecycle is busy or ambiguous') from None
            time.sleep(0.1)
    marker = None
    try:
        (lock / 'pid').write_text(str(os.getpid()) + '\n')
        if not safe_path(state, primary):
            raise ValueError('Unsafe shared build lease state')
        state.mkdir(parents=True, exist_ok=True)
        marker = state / f'{os.getpid()}-{uuid.uuid4().hex}.slot'
        try:
            from internal.resource_lease import make_scope
            scope = make_scope(os.getpid(), root, [str(path) for path in paths])
        except (ImportError, OSError, ValueError, RuntimeError, subprocess.SubprocessError):
            scope = ''  # Legacy-wide protection is safer than an incomplete scope.
        with marker.open('x') as stream:
            stream.write(f'{os.getpid()} build {scope}\n')
    finally:
        (lock / 'pid').unlink(missing_ok=True)
        lock.rmdir()
    try:
        yield
    finally:
        if marker and not marker.is_symlink():
            try:
                if marker.read_text().split()[0] == str(os.getpid()):
                    marker.unlink()
            except (OSError, IndexError):
                pass
