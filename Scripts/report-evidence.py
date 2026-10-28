#!/usr/bin/env python3
"""Inventory retained evidence and byte-compare duplicates without changing it."""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import time

from internal.cli import ROOT


def identity(info):
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def open_checked(path, expected):
    descriptor = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0))
    stream = os.fdopen(descriptor, 'rb')
    if identity(os.fstat(stream.fileno())) != expected:
        stream.close()
        raise ValueError('file changed before read')
    return stream


def digest(path, expected):
    value = hashlib.sha256()
    with open_checked(path, expected) as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
        if identity(os.fstat(stream.fileno())) != expected:
            raise ValueError('file changed while hashing')
    if identity(path.lstat()) != expected:
        raise ValueError('file replaced while hashing')
    return value.hexdigest()


def identical(left, right):
    with open_checked(left['path'], left['identity']) as a, open_checked(right['path'], right['identity']) as b:
        while True:
            x, y = a.read(1024 * 1024), b.read(1024 * 1024)
            if x != y:
                return False
            if not x:
                break
        if identity(os.fstat(a.fileno())) != left['identity'] or identity(os.fstat(b.fileno())) != right['identity']:
            raise ValueError('file changed while comparing')
    if identity(left['path'].lstat()) != left['identity'] or identity(right['path'].lstat()) != right['identity']:
        raise ValueError('file replaced while comparing')
    return True


def category(path):
    if any(part.endswith('.xcresult') for part in path.parts): return 'native test results'
    if any(part.endswith('.xcarchive') for part in path.parts): return 'release archives'
    if any(part.endswith('.dSYM') for part in path.parts): return 'debug symbols'
    if any(part.endswith('.trace') for part in path.parts): return 'performance traces'
    if path.suffix.lower() in {'.png', '.jpg', '.jpeg', '.heic', '.mp4', '.mov'}: return 'visual media'
    if path.suffix.lower() in {'.zip', '.gz', '.ipa', '.tar'}: return 'compressed archives'
    if path.suffix.lower() in {'.json', '.jsonl', '.log', '.txt', '.xml', '.md', '.csv'}: return 'reports and logs'
    return 'other files'


def active_branches(root):
    output = subprocess.check_output(['git', '-C', str(root), 'worktree', 'list', '--porcelain', '-z'], timeout=15)
    return {os.fsdecode(part[len(b'branch refs/heads/'):]) for part in output.split(b'\0')
            if part.startswith(b'branch refs/heads/')}


def audit(common, root):
    evidence = common / 'trinket-evidence/codex'
    if evidence.is_symlink() or evidence.parent.is_symlink() or not evidence.is_dir():
        raise ValueError('Evidence root is unavailable or unsafe')
    active = active_branches(root)
    sizes = defaultdict(list)
    manifests = {}
    totals = defaultdict(lambda: {'files': 0, 'logical_bytes': 0, 'allocated_bytes': 0})
    issues = []
    count = 0
    now = time.time()
    for base, directories, files in os.walk(evidence, followlinks=False):
        current = Path(base)
        for name in list(directories):
            if (current / name).is_symlink():
                issues.append({'path': str((current / name).relative_to(evidence)), 'reason': 'symlink directory skipped'})
                directories.remove(name)
        for name in files:
            path = current / name
            relative = path.relative_to(evidence)
            try:
                info = path.lstat()
                if not stat.S_ISREG(info.st_mode):
                    issues.append({'path': str(relative), 'reason': 'non-regular file skipped'})
                    continue
                kind = category(relative)
                totals[kind]['files'] += 1
                totals[kind]['logical_bytes'] += info.st_size
                totals[kind]['allocated_bytes'] += info.st_blocks * 512
                reasons = []
                if relative.parts and 'codex/' + relative.parts[0] in active:
                    reasons.append('registered worktree')
                for ancestor in [path, *[p for p in path.parents if p.is_relative_to(evidence)]]:
                    marker = ancestor / '.retention-keep' if ancestor.is_dir() else ancestor.with_name(ancestor.name + '.retention-keep')
                    if marker.exists() or marker.is_symlink():
                        reasons.append('keep marker')
                        break
                if info.st_mtime > now - 7 * 86400:
                    reasons.append('modified within seven days')
                snapshot = relative.parts[:2]
                if len(relative.parts) >= 4 and relative.parts[2] == 'files' and snapshot not in manifests:
                    manifest = evidence.joinpath(*snapshot) / 'evidence.json'
                    try:
                        if manifest.is_symlink():
                            raise ValueError('symlink manifest')
                        saved = json.loads(manifest.read_text())
                        if saved['branch'] != 'codex/' + relative.parts[0] or not isinstance(saved['files'], list):
                            raise ValueError('invalid manifest')
                        manifests[snapshot] = set(saved['files'])
                    except (OSError, ValueError, KeyError, TypeError):
                        manifests[snapshot] = set()
                if (len(relative.parts) < 4 or relative.parts[2] != 'files'
                        or str(Path(*relative.parts[3:])) not in manifests.get(snapshot, set())):
                    reasons.append('unclassified snapshot metadata')
                sizes[info.st_size].append({'path': path, 'relative': str(relative), 'category': kind,
                                            'identity': identity(info), 'reasons': reasons})
                count += 1
            except OSError as error:
                issues.append({'path': str(relative), 'reason': str(error)})
    groups = []
    hashed = 0
    for length, items in sizes.items():
        if len(items) < 2:
            continue
        by_hash = defaultdict(list)
        for item in items:
            try:
                by_hash[digest(item['path'], item['identity'])].append(item)
                hashed += 1
            except (OSError, ValueError) as error:
                issues.append({'path': item['relative'], 'reason': str(error)})
        for checksum, matches in by_hash.items():
            if len(matches) < 2:
                continue
            verified = []
            reference = matches[0]
            for item in matches[1:]:
                try:
                    if identical(reference, item):
                        verified.append(item)
                except (OSError, ValueError) as error:
                    issues.append({'path': item['relative'], 'reason': str(error)})
            if verified:
                members = [reference, *verified]
                groups.append({'sha256': checksum, 'bytes_per_file': length,
                               'members': [{'path': m['relative'], 'category': m['category'],
                                            'protection': m['reasons']} for m in members]})
    groups.sort(key=lambda group: group['bytes_per_file'] * (len(group['members']) - 1), reverse=True)
    return {'schema': 1, 'root': str(evidence), 'files': count, 'hashed_files': hashed,
            'categories': dict(totals), 'duplicate_groups': groups, 'issues': issues,
            'note': 'Byte comparisons are a point-in-time inventory, not deletion eligibility. Open files, ownership, metadata and APFS shared extents require separate checks.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    try:
        common = Path(subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', '--path-format=absolute',
                                               '--git-common-dir'], text=True, timeout=15).strip()).resolve()
        print(json.dumps(audit(common, ROOT), indent=2))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(f'Evidence audit incomplete: {error}')


if __name__ == '__main__':
    main()
