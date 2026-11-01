"""Retire artifacts for superseded completed releases, preserving all receipts."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import time

from internal import build_symbols, output_retention, release_retention
from internal.cli import worktree_roots


def release_identity(receipt: dict) -> tuple[tuple[int, ...], int]:
    parts = tuple(map(int, receipt['version'].split('.')))
    return parts + (0,) * (3 - len(parts)), int(receipt['build'])


def superseded(receipt: dict, latest: dict) -> bool:
    return receipt.get('stage') == 'ready' and release_identity(receipt) < latest[receipt['bundle_id']]


def inventory(root: Path) -> tuple[list[tuple[Path, dict]], dict[str, tuple[tuple[int, ...], int]]]:
    records = []
    latest = {}
    for checkout in worktree_roots(root):
        state = checkout / '.DerivedData/testflight'
        if state.is_symlink():
            raise ValueError(f'Unsafe deployment state: {state}')
        for path in sorted(state.glob('*/receipt.json')):
            if not output_retention.safe_path(path, checkout):
                raise ValueError(f'Unsafe release receipt: {path}')
            value = json.loads(path.read_text())
            if value.get('schema') != 1 or not isinstance(value.get('stage'), str):
                raise ValueError(f'Unknown release receipt: {path}')
            records.append((path, value))
            if value['stage'] == 'ready':
                build = str(value['build'])
                version = value.get('version')
                if (not re.fullmatch(r'\d+', build) or not isinstance(value.get('bundle_id'), str)
                        or not value['bundle_id'] or not isinstance(version, str)
                        or not re.fullmatch(r'\d+(?:\.\d+){0,2}', version)):
                    raise ValueError(f'Unknown completed release identity: {path}')
                identity = release_identity(value)
                key = value['bundle_id']
                latest[key] = max(latest.get(key, identity), identity)
    return records, latest


def candidates(root: Path, artifact_root: Path) -> list[tuple[Path, Path, dict, Path]]:
    records, latest = inventory(root)
    referenced = {}
    for receipt_path, receipt in records:
        backup = receipt.get('symbol_artifacts') or {}
        if isinstance(backup, dict) and isinstance(backup.get('path'), str):
            referenced.setdefault(backup['path'], []).append((receipt_path, receipt))
    result = []
    releases = artifact_root / 'releases'
    for receipt_path, receipt in records:
        if receipt['stage'] != 'ready':
            continue
        if not superseded(receipt, latest):
            continue
        run = receipt_path.parent
        for field in ('archive', 'ipa'):
            value = receipt.get(field)
            if isinstance(value, str):
                path = Path(value)
                expected = 'Trinket.xcarchive' if field == 'archive' else 'Trinket.ipa'
                if path.is_absolute() and path.is_relative_to(run) and path.name == expected:
                    result.append((path, receipt_path, receipt, run))
        # Older attempts within a completed run can leave additional release
        # archives and exports even after the receipt moved to a later attempt.
        for attempt in sorted(run.glob('artifacts-*')):
            if attempt.is_symlink() or not attempt.is_dir() or not re.fullmatch(r'artifacts-[a-f0-9]+', attempt.name):
                continue
            extra = [attempt / 'Trinket.xcarchive']
            extra.extend(path / 'Trinket.ipa' for path in attempt.glob('export*')
                         if path.is_dir() and not path.is_symlink())
            extra.extend(attempt / 'DerivedData' / name for name in
                         ('ModuleCache.noindex', 'SDKExplicitPrecompiledModules', 'SDKStatCaches.noindex',
                          'Build/Intermediates.noindex', 'Build/Products'))
            for path in extra:
                result.append((path, receipt_path, receipt, run))
        backup = receipt.get('symbol_artifacts') or {}
        if not isinstance(backup, dict) or backup.get('status') != 'verified' or not isinstance(backup.get('path'), str):
            continue
        saved = Path(backup['path'])
        if saved.parent != releases or not re.fullmatch(r'[0-9a-f]{64}', saved.name):
            continue
        # Shared artifacts remain protected if any reference is current or unfinished.
        if any(not superseded(other, latest) for _, other in referenced[str(saved)]):
            continue
        for name in ('Trinket.xcarchive', 'Trinket.ipa'):
            result.append((saved / name, receipt_path, receipt, releases))
    unique = {}
    for path, source, receipt, boundary in result:
        used_by_live = any(not superseded(other, latest) for _, other in records
                           for field in ('archive', 'ipa') if isinstance(other.get(field), str)
                           and (Path(other[field]) == path or Path(other[field]).is_relative_to(path)))
        if not used_by_live:
            unique[(path, source)] = (path, source, receipt, boundary)
    return list(unique.values())


def cleanup(root: Path, *, apply: bool, artifact_root: Path | None = None) -> tuple[int, int]:
    artifact_root = artifact_root or build_symbols.artifact_root()
    count = total = 0
    with release_retention.deployment_lock(root, apply):
        for path, receipt_path, receipt, boundary in candidates(root, artifact_root):
            if not path.exists() or not output_retention.safe_path(path, boundary):
                continue
            with output_retention.lifecycle_guard(root, apply=apply) as admitted:
                if not admitted:
                    print(f'SKIP {path}: lifecycle lock busy')
                    continue
                processes = output_retention.process_snapshot()
                processes.pop(os.getpid(), None)
                reason = output_retention.protection(path, boundary, processes, scoped=True)
                # A keep or owner on the run also protects its external backup.
                reason = reason or output_retention.protection(receipt_path.parent, receipt_path.parents[2].parent, processes, scoped=True)
                if reason:
                    print(f'SKIP {path}: {reason}')
                    continue
                opened = subprocess.run(['lsof', '-n', '-P', *(['+D', str(path)] if path.is_dir() else ['--', str(path)])],
                                        capture_output=True, text=True, timeout=30)
                if opened.returncode != 1 or opened.stdout.strip() or opened.stderr.strip():
                    print(f'SKIP {path}: open files or unavailable inventory')
                    continue
                newest, size = output_retention.metadata(path)
                if apply:
                    # Recompute current/in-progress records while both producer locks are held.
                    if not any(item[0] == path and item[1] == receipt_path and item[2] == receipt
                               for item in candidates(root, artifact_root)):
                        print(f'SKIP {path}: release inventory changed')
                        continue
                    journal = receipt_path.parent / 'artifact-expiry.jsonl'
                    if journal.is_symlink():
                        continue
                    with journal.open('a') as stream:
                        stream.write(json.dumps({'path': str(path), 'retired_at': time.time(), 'build': receipt['build']}) + '\n')
                        stream.flush()
                        os.fsync(stream.fileno())
                    final_processes = output_retention.process_snapshot()
                    final_open = subprocess.run(['lsof', '-n', '-P', *(['+D', str(path)] if path.is_dir() else ['--', str(path)])],
                                                capture_output=True, text=True, timeout=30)
                    if (output_retention.protection(path, boundary, final_processes, scoped=True)
                            or output_retention.protection(receipt_path.parent, receipt_path.parents[2].parent, final_processes, scoped=True)
                            or output_retention.metadata(path)[0] != newest
                            or final_open.returncode != 1 or final_open.stdout.strip() or final_open.stderr.strip()):
                        continue
                    output_retention.remove(path)
                count += 1
                total += size
                print(f'{"REMOVE" if apply else "WOULD REMOVE"} retired release {path}: {size} allocated bytes')
    print(f'{"Removed" if apply else "Eligible"} retired release artifacts: {count}, {total} allocated bytes (APFS extents may be shared).')
    return count, total
