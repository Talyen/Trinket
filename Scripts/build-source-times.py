#!/usr/bin/env python3
"""Keep unchanged checkout inputs incremental after a DerivedData cache restore."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess

from internal.cli import ROOT, write_json_atomic


def inputs(root):
    paths = subprocess.check_output(['git', '-C', str(root), 'ls-files', '-z']).split(b'\0')
    for encoded in filter(None, paths):
        name = os.fsdecode(encoded)
        path = root / name
        if (not name.endswith('.md') and (name.startswith(('Trinket/', 'TrinketUITests/', 'Packages/'))
                or name in ('project.yml', 'Trinket.xcodeproj/project.pbxproj') or name.endswith('.xctestplan'))
                and not path.is_symlink() and path.resolve().is_relative_to(root.resolve()) and path.is_file()):
            yield name, path


def signature(path):
    before = path.stat()
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    after = path.stat()
    if (before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (
            after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns):
        return None
    return dict(sha256=digest.hexdigest(), size=after.st_size, mode=stat.S_IMODE(after.st_mode), mtime_ns=after.st_mtime_ns)


def process(root, action):
    state = root / '.DerivedData/build-source-times.json'
    if state.parent.is_symlink():
        raise ValueError('Refusing a symlinked DerivedData source-time manifest')
    context = dict(root=str(root.resolve()), developer=os.environ.get('DEVELOPER_DIR'),
                   xcode_build=os.environ.get('XCODE_BUILD'))
    saved = {}
    if action == 'restore':
        try:
            payload = json.loads(state.read_text())
            if payload.get('schema') == 1 and payload.get('context') == context and isinstance(payload.get('files'), dict):
                saved = payload['files']
        except (OSError, ValueError, AttributeError):
            pass
        if not saved:
            print('No matching source timestamps; keeping ordinary Xcode dependency checks.')
            return 0
    records, restored = {}, 0
    for name, path in inputs(root):
        current = signature(path)
        if current is None:
            continue
        if action == 'record':
            records[name] = current
            continue
        previous = saved.get(name)
        if (isinstance(previous, dict) and type(previous.get('mtime_ns')) is int and previous['mtime_ns'] > 0
                and all(previous.get(key) == current[key] for key in ('sha256', 'size', 'mode'))):
            # Only timestamps change, after byte comparison; changed inputs remain fresh.
            os.utime(path, ns=(path.stat().st_atime_ns, previous['mtime_ns']))
            restored += 1
    if action == 'record':
        state.parent.mkdir(parents=True, exist_ok=True)
        write_json_atomic(state, dict(schema=1, context=context, files=records))
        print(f'Recorded timestamps for {len(records)} build inputs.')
    else:
        print(f'Restored timestamps for {restored} byte-identical build inputs; changed files stay fresh.')
    return restored


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('restore', 'record'))
    process(ROOT, parser.parse_args().action)
