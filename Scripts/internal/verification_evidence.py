"""Reuse executed compiled checks only for identical source and toolchain inputs."""
from __future__ import annotations

import hashlib
import json
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


def required_compilation(root: Path, paths: list[str], base: str):
    from internal.change_routing import automatic_plan, classify
    checks = automatic_plan(classify(paths, root, base=base), root=root, environment=dict(os.environ))
    return [check for check in checks if not check.deferred and (check.id == 'build' or check.id.startswith('package:'))]


def missing_compilation(root: Path, checks) -> list[str]:
    if not checks:
        return []
    source = source_identity(root)
    toolchain = toolchain_identity(root)
    outcomes = {}
    directory = root / '.DerivedData/Deliverables/Verification'
    for report in sorted(directory.glob('*.json'), key=lambda path: path.stat().st_mtime_ns):
        if report.is_symlink():
            continue
        try:
            data = json.loads(report.read_text())
            if data.get('source_identity') != source or data.get('toolchain') != toolchain:
                continue
            for check in data.get('checks', []):
                if check.get('outcome') in {'passed', 'failed', 'unavailable'}:
                    outcomes[(check['id'], tuple(check.get('argv', [])))] = check['outcome']
        except (OSError, ValueError, KeyError, TypeError):
            continue
    return [check.id for check in checks if outcomes.get((check.id, check.argv)) != 'passed']
