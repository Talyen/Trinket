"""Record source and toolchain provenance for explicitly executed compiled checks."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import stat
import subprocess


def source_identity(root: Path) -> str:
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=root)
    entries = {}
    for row in git('ls-files', '--stage', '-z').split(b'\0'):
        if not row:
            continue
        metadata, name = row.split(b'\t', 1)
        mode, blob, stage = metadata.split()
        if stage != b'0':
            raise ValueError('Cannot verify an unresolved index')
        entries[name] = (mode, blob)
    changed = git('diff-files', '--name-only', '-z').split(b'\0')
    untracked = git('ls-files', '--others', '--exclude-standard', '-z').split(b'\0')
    for name in set(changed + untracked) - {b''}:
        path = root / os.fsdecode(name)
        if not path.exists() and not path.is_symlink():
            entries.pop(name, None)
            continue
        if path.is_dir():
            raise ValueError(f'Source identity does not support a changed submodule: {path}')
        content = os.fsencode(os.readlink(path)) if path.is_symlink() else path.read_bytes()
        mode = b'120000' if path.is_symlink() else b'100755' if path.stat().st_mode & stat.S_IXUSR else b'100644'
        blob = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest().encode()
        entries[name] = (mode, blob)
    # Guidance-only edits do not change compiled products or behavior checks.
    def compiled_input(name):
        path = os.fsdecode(name)
        return not (path.endswith('.md') or path.startswith(('.agents/', '.github/', 'ReleaseNotes/')))
    return hashlib.sha256(b'\0'.join(name + b'\0' + b' '.join(entries[name])
                                      for name in sorted(entries) if compiled_input(name))).hexdigest()


def toolchain_identity(root: Path) -> dict:
    developer = os.environ.get('DEVELOPER_DIR', '')
    result = subprocess.run(['xcodebuild', '-version'], cwd=root, capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise ValueError('Cannot identify the selected Xcode toolchain')
    return {'developer_dir': developer, 'xcode': result.stdout.strip(), 'architecture': os.uname().machine}
