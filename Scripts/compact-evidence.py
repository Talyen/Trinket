#!/usr/bin/env python3
"""Losslessly compact inactive evidence without changing its paths or contents."""
from __future__ import annotations

import argparse
import ctypes
import fcntl
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import time

from internal.cli import ROOT

TEXT = {'.json', '.jsonl', '.log', '.txt', '.md'}
MEDIA = {'.png', '.mp4', '.jpg', '.jpeg'}
MINIMUM = 1024 * 1024
MAXIMUM = 128 * 1024 * 1024
AGE = 7 * 86400


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def identity(path: Path) -> tuple:
    info = path.lstat()
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def safe(path: Path, common: Path, active: set[str], now: float) -> bool:
    try:
        rel = path.relative_to(common / 'trinket-evidence' / 'codex')
        if len(rel.parts) < 5 or 'codex/' + rel.parts[0] in active:
            return False
        if 'Verification' in rel.parts or any(part.endswith(('.xcresult', '.xcarchive', '.dSYM', '.trace')) for part in rel.parts):
            return False
        if any(ord(c) < 32 for c in str(rel)):
            return False
        parents = [path, *[p for p in path.parents if p.is_relative_to(common)]]
        if any(p.is_symlink() for p in parents):
            return False
        for parent in parents:
            marker = parent / '.retention-keep' if parent.is_dir() else parent.with_name(parent.name + '.retention-keep')
            if marker.exists() or marker.is_symlink():
                return False
        info = path.lstat()
        if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1
                or not MINIMUM <= info.st_size <= MAXIMUM or info.st_mtime > now - AGE):
            return False
        listing = subprocess.run(['/bin/ls', '-lde', str(path)], capture_output=True, text=True, timeout=5)
        if listing.returncode != 0 or len(listing.stdout.splitlines()) != 1:
            return False  # Preserve ACL-bearing and unreadable files.
        opened = subprocess.run(['lsof', '-n', '-P', '--', str(path)], capture_output=True, text=True, timeout=5)
        return opened.returncode == 1 and not opened.stdout.strip() and not opened.stderr.strip()
    except (OSError, ValueError, subprocess.SubprocessError):
        return False


def attributes(path: Path) -> bytes:
    result = subprocess.run(['/usr/bin/xattr', '-l', str(path)], capture_output=True, timeout=5, check=True)
    return result.stdout


def metadata(path: Path) -> tuple:
    info = path.stat()
    flags = getattr(info, 'st_flags', 0) & ~getattr(stat, 'UF_COMPRESSED', 0)
    return (stat.S_IMODE(info.st_mode), info.st_uid, info.st_gid, info.st_mtime_ns, flags, attributes(path))


def active_branches(root: Path) -> set[str]:
    result = subprocess.check_output(['git', '-C', str(root), 'worktree', 'list', '--porcelain', '-z'], timeout=5)
    return {os.fsdecode(part[len(b'branch refs/heads/'):]) for part in result.split(b'\0')
            if part.startswith(b'branch refs/heads/')}


def candidate_files(common: Path):
    root = common / 'trinket-evidence' / 'codex'
    if not root.is_dir() or root.is_symlink() or root.parent.is_symlink():
        return
    for branch in sorted(root.iterdir()):
        if branch.is_symlink() or not branch.is_dir():
            continue
        for manifest in sorted(branch.glob('*/evidence.json')):
            snapshot = manifest.parent
            if snapshot.is_symlink() or manifest.is_symlink():
                continue
            try:
                saved = json.loads(manifest.read_text())
                if saved['branch'] != 'codex/' + branch.name or not isinstance(saved['files'], list):
                    continue
                for name in saved['files']:
                    rel = Path(name)
                    if rel.is_absolute() or '..' in rel.parts or not rel.parts or rel.suffix.lower() not in TEXT | MEDIA:
                        continue
                    yield branch.name, str(rel), snapshot / 'files' / rel
            except (OSError, ValueError, KeyError, TypeError):
                continue


def compact(common: Path, root: Path, *, seconds: float = 12, max_attempts: int = 4) -> tuple[int, int]:
    if sys.platform != 'darwin':
        return 0, 0
    maintenance = common / 'trinket-storage-maintenance'
    if maintenance.is_symlink():
        return 0, 0
    maintenance.mkdir(mode=0o700, exist_ok=True)
    journal = maintenance / 'processed.jsonl'
    if journal.is_symlink():
        return 0, 0
    start, now, attempts, changed, saved_bytes = time.monotonic(), time.time(), 0, 0, 0
    with journal.open('a+') as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0, 0
        stream.seek(0)
        seen = set()
        for line in stream:
            try:
                item = json.loads(line)
                seen.add(item['key'])
            except (ValueError, KeyError, TypeError):
                return 0, 0
        active = active_branches(root)
        for temporary in maintenance.glob('.compact-*'):
            try:
                info = temporary.lstat()
                opened = subprocess.run(['lsof', '-n', '-P', '--', str(temporary)], capture_output=True, text=True, timeout=5)
                if (stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid() and info.st_mtime <= now - 86400
                        and opened.returncode == 1 and not opened.stdout.strip() and not opened.stderr.strip()):
                    temporary.unlink()
            except (OSError, subprocess.SubprocessError):
                continue
        groups = {}
        for branch, relative, path in candidate_files(common):
            if time.monotonic() - start >= seconds or attempts >= max_attempts:
                break
            key = None
            try:
                info = path.lstat()
                if not stat.S_ISREG(info.st_mode) or not MINIMUM <= info.st_size <= MAXIMUM:
                    continue
                key = json.dumps([str(path.relative_to(common)), *identity(path)], separators=(',', ':'))
                group = (branch, relative, info.st_size)
                previous = groups.get(group)
                groups.setdefault(group, path)
                if key in seen or not safe(path, common, active, now):
                    continue
                attempts += 1
                before = identity(path)
                source_hash = digest(path)
                source_meta = metadata(path)
                descriptor, name = tempfile.mkstemp(prefix='.compact-', dir=maintenance)
                os.close(descriptor)
                temp = Path(name)
                temp.unlink()
                try:
                    action = 'compress'
                    cloned = False
                    if previous and previous != path and safe(previous, common, active, now):
                        previous_before = identity(previous)
                        if digest(previous) == source_hash and metadata(previous) == source_meta:
                            clone = getattr(ctypes.CDLL(None, use_errno=True), 'clonefile', None)
                            if clone is not None:
                                clone.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint32]
                                clone.restype = ctypes.c_int
                                cloned = clone(os.fsencode(previous), os.fsencode(temp), 1) == 0
                                if cloned and identity(previous) != previous_before:
                                    cloned = False
                            if cloned:
                                action = 'clone'
                    if not cloned:
                        if temp.exists() or temp.is_symlink():
                            continue
                        if path.suffix.lower() not in TEXT:
                            continue
                        result = subprocess.run(['/usr/bin/ditto', '--hfsCompression', '--noclone', str(path), str(temp)],
                                                capture_output=True, timeout=8)
                        if result.returncode or not temp.is_file():
                            continue
                    temp_info = temp.stat()
                    if (digest(temp) != source_hash or metadata(temp) != source_meta or identity(path) != before
                            or not safe(path, common, active_branches(root), time.time())):
                        continue
                    # Compression only replaces a file when it actually allocates less.
                    if action == 'compress' and temp_info.st_blocks >= info.st_blocks:
                        continue
                    with temp.open('rb') as candidate:
                        os.fsync(candidate.fileno())
                    os.replace(temp, path)
                    changed += 1
                    if action == 'compress':
                        saved_bytes += max(0, (info.st_blocks - temp_info.st_blocks) * 512)
                finally:
                    temp.unlink(missing_ok=True)
                    # Remember unchanged attempts as well, to make bounded passes progress.
                    if path.exists() and not path.is_symlink():
                        key = json.dumps([str(path.relative_to(common)), *identity(path)], separators=(',', ':'))
                        stream.seek(0, os.SEEK_END)
                        stream.write(json.dumps({'key': key}) + '\n')
                        stream.flush()
                        seen.add(key)
            except (OSError, ValueError, subprocess.SubprocessError):
                if key is not None:
                    stream.seek(0, os.SEEK_END)
                    stream.write(json.dumps({'key': key}) + '\n')
                    stream.flush()
                    seen.add(key)
                continue
    return changed, saved_bytes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--time-limit', type=float, default=12)
    args = parser.parse_args()
    if not 0 < args.time_limit <= 15:
        parser.error('--time-limit must be within 0 to 15 seconds')
    common = Path(subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', '--path-format=absolute',
                                           '--git-common-dir'], text=True, timeout=5).strip()).resolve()
    changed, allocated = compact(common, ROOT, seconds=args.time_limit)
    print(f'Compacted {changed} evidence file(s); per-file allocation fell by {allocated} bytes (shared extents may affect actual savings).')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(f'Evidence compaction deferred: {error}')
