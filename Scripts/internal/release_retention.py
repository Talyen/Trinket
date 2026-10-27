"""Retire verified TestFlight duplicates without expiring releases or reservations."""

from __future__ import annotations

from contextlib import contextmanager
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import zipfile

from internal import build_symbols as symbols
from internal import output_retention as retention
from internal.cli import legacy_runtime_owner

MAX_AGE = 24 * 3600


@contextmanager
def deployment_lock(root: Path, apply: bool):
    """Use deployment's own directory lock; never reclaim an existing owner."""
    lock = root / '.DerivedData/testflight/.deploy.lock'
    if not retention.safe_path(lock, root):
        raise ValueError('Unsafe deployment lock')
    if legacy_runtime_owner(root, ('testflight/.deploy.lock',)) is not None or lock.exists():
        raise ValueError('Live or ambiguous deployment lock; release cleanup deferred')
    if not apply:
        yield
        return
    lock.mkdir()
    try:
        (lock / 'pid').write_text(str(os.getpid()) + '\n')
        yield
    finally:
        (lock / 'pid').unlink()
        lock.rmdir()


def completed_time(receipt: dict, path: Path) -> float:
    value = receipt.get('completed_at')
    if value is None:
        # Legacy ready receipts have no transition timestamp. Their last write
        # is a conservative upper bound, never the directory creation time.
        return path.stat().st_mtime
    parsed = datetime.fromisoformat(value)
    if parsed.tzinfo is None:
        raise ValueError('Completion time lacks a timezone')
    return parsed.timestamp()


def extracted_hashes(ipa: Path) -> dict[str, str]:
    values = {}
    with zipfile.ZipFile(ipa) as zipped:
        for entry in zipped.infolist():
            if entry.is_dir():
                continue
            name = Path(entry.filename)
            if name.is_absolute() or '..' in name.parts or entry.filename in values:
                raise ValueError('Unsafe or duplicate IPA member')
            with zipped.open(entry) as stream:
                value = hashlib.sha256()
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    value.update(block)
                values[entry.filename] = value.hexdigest()
    return values


def working_copies(run: Path, receipt: dict) -> list[tuple[Path, str]]:
    result = []
    for field, kind in (('archive', 'archive'), ('ipa', 'ipa')):
        path = Path(receipt[field])
        if path.is_absolute() and path.is_relative_to(run) and path.exists():
            result.append((path, kind))
    for artifacts in run.glob('artifacts-*'):
        if artifacts.is_symlink() or not artifacts.is_dir():
            continue
        for pattern in ('inspection', 'inspection-*', 'symbol-recovery-inspection'):
            result.extend((path, 'extraction') for path in artifacts.glob(pattern) if path.is_dir())
    return result


def receipt_digest(receipt: dict) -> str:
    return hashlib.sha256(json.dumps(receipt, sort_keys=True).encode()).hexdigest()


def finish_retired_copy(retired: Path) -> None:
    contents = retired / 'contents'
    if contents.exists() or contents.is_symlink():
        retention.remove(contents)
    (retired / 'retired.json').unlink()
    retired.rmdir()


def retire_working_copy(path: Path, run: Path, kind: str, receipt: dict, root: Path) -> None:
    """Detach a verified duplicate so an interrupted deletion remains resumable."""
    parent = run / '.retired-copies'
    if not retention.safe_path(parent, root):
        raise ValueError('Unsafe retired release directory')
    parent.mkdir(exist_ok=True)
    retired = Path(tempfile.mkdtemp(prefix='copy-', dir=parent))
    try:
        from internal.cli import write_json_atomic
        write_json_atomic(retired / 'retired.json', {'schema': 1, 'original': str(path.relative_to(run)),
                                                     'kind': kind, 'receipt_sha256': receipt_digest(receipt)})
        path.rename(retired / 'contents')
    except BaseException:
        if not (retired / 'contents').exists():
            shutil.rmtree(retired)
        raise
    finish_retired_copy(retired)


def retire_interrupted(run: Path, receipt_path: Path, receipt: dict, preserved: Path, manifest: dict,
                       root: Path, now: float, apply: bool, processes: dict, emit) -> tuple[int, int]:
    """Finish interrupted removals only while every surviving byte matches the backup."""
    parent = run / '.retired-copies'
    if not retention.safe_path(parent, root) or not parent.is_dir():
        return 0, 0
    count = total = 0
    for retired in parent.glob('copy-*'):
        marker = retired / 'retired.json'
        try:
            if not retention.safe_path(retired, root) or marker.is_symlink():
                continue
            record = json.loads(marker.read_text())
            original = Path(record['original'])
            kind = record['kind']
            if (record['schema'] != 1 or record['receipt_sha256'] != receipt_digest(receipt)
                    or kind not in ('archive', 'ipa', 'extraction') or original.is_absolute() or '..' in original.parts
                    or {p.name for p in retired.iterdir()} - {'retired.json', 'contents'}):
                continue
            newest, size = retention.metadata(retired)
            if newest > now - MAX_AGE or retention.protection(retired, root, processes):
                continue
            opened = subprocess.run(['lsof', '-n', '-P', '+D', str(retired)], capture_output=True, text=True, timeout=30)
            if opened.returncode != 1 or opened.stdout.strip() or opened.stderr.strip():
                continue
            contents = retired / 'contents'
            if contents.is_symlink():
                continue
            if contents.exists():
                if kind == 'ipa':
                    if not contents.is_file() or symbols.digest(contents) != manifest['ipaSHA256']:
                        continue
                else:
                    expected = manifest['archiveFiles'] if kind == 'archive' else extracted_hashes(preserved / 'Trinket.ipa')
                    if not contents.is_dir() or any(expected.get(k) != v for k, v in symbols.tree_hashes(contents).items()):
                        continue
            if apply:
                symbols.verified_release(receipt)
                if (json.loads(receipt_path.read_text()) != receipt
                        or retention.protection(retired, root, retention.process_snapshot())
                        or retention.metadata(retired)[0] > now - MAX_AGE):
                    continue
                finish_retired_copy(retired)
            count += 1
            total += size
            emit(f'{"REMOVE" if apply else "WOULD REMOVE"} interrupted release duplicate {retired}')
        except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, zipfile.BadZipFile):
            continue
    return count, total


def cleanup(root: Path, *, apply: bool, now: float | None = None, verbose: bool = True,
            max_verify: int | None = None, decisions: list | None = None) -> tuple[int, int]:
    now = time.time() if now is None else now
    emit = print if verbose else lambda *args: None
    state = root / '.DerivedData/testflight'
    if not state.is_dir() or not retention.safe_path(state, root):
        return 0, 0
    removed = allocated = verified = 0
    with deployment_lock(root, apply):
        processes = retention.process_snapshot()
        processes.pop(os.getpid(), None)
        for receipt_path in sorted(state.glob('*/receipt.json')):
            run = receipt_path.parent
            try:
                if not retention.safe_path(receipt_path, root):
                    raise ValueError('Unsafe receipt')
                receipt = json.loads(receipt_path.read_text())
                if receipt.get('schema') != 1 or receipt.get('stage') not in ('ready', 'exported'):
                    raise ValueError('Deployment is unfinished or has unknown state')
                reason = retention.protection(run, root, processes)
                if reason:
                    raise ValueError(reason)
                pending = run / '.retired-copies'
                if not working_copies(run, receipt) and not (pending.is_dir() and not pending.is_symlink()):
                    emit(f'RETAIN receipt {receipt_path}: no duplicate working copies remain')
                    continue
                if max_verify is not None and verified >= max_verify:
                    break
                if not receipt.get('symbol_artifacts', {}).get('path'):
                    raise ValueError('No authoritative backup recorded; original artifacts preserved')
                verified += 1
                preserved, manifest = symbols.verified_release(receipt)
                preserved_at = (preserved / 'symbol-manifest.json').stat().st_mtime
                eligible_at = max(completed_time(receipt, receipt_path), preserved_at) + MAX_AGE
                emit(f'RETAIN release-backup {preserved}: verified archive, IPA and symbols; '
                     f'allocatedBytes={retention.metadata(preserved)[1]}; no expiry')
                if now < eligible_at:
                    raise ValueError(f'Duplicate grace period ends at {eligible_at:.0f}')
                count, size = retire_interrupted(run, receipt_path, receipt, preserved, manifest,
                                                 root, now, apply, processes, emit)
                removed += count
                allocated += size
                expanded = None
                for path, kind in working_copies(run, receipt):
                    if not retention.safe_path(path, root):
                        emit(f'SKIP {path}: symlink or escaping path')
                        continue
                    newest, size = retention.metadata(path)
                    current = retention.process_snapshot() if apply else processes
                    current.pop(os.getpid(), None)
                    reason = retention.protection(path, root, current)
                    if reason or newest > now - MAX_AGE:
                        emit(f'SKIP {path}: {reason or "recent writes"}; allocatedBytes={size}')
                        continue
                    opened = subprocess.run(['lsof', '-n', '-P', '+D' if path.is_dir() else '--', str(path)],
                                            capture_output=True, text=True, timeout=30)
                    if opened.returncode != 1 or opened.stdout.strip() or opened.stderr.strip():
                        emit(f'SKIP {path}: open files or unavailable inventory; allocatedBytes={size}')
                        continue
                    if kind == 'archive':
                        matches = symbols.tree_hashes(path) == manifest['archiveFiles']
                    elif kind == 'ipa':
                        matches = symbols.digest(path) == manifest['ipaSHA256']
                    else:
                        if expanded is None:
                            expanded = extracted_hashes(preserved / 'Trinket.ipa')
                        matches = symbols.tree_hashes(path) == expanded
                    if not matches:
                        emit(f'SKIP {path}: working copy differs from preserved release; allocatedBytes={size}')
                        continue
                    if apply:
                        # Revalidate durable recovery immediately before each removal.
                        symbols.verified_release(receipt)
                        final_processes = retention.process_snapshot()
                        final_processes.pop(os.getpid(), None)
                        if (json.loads(receipt_path.read_text()) != receipt
                                or retention.protection(path, root, final_processes)
                                or retention.metadata(path)[0] > now - MAX_AGE):
                            emit(f'SKIP {path}: receipt or owner changed')
                            continue
                        retire_working_copy(path, run, kind, receipt, root)
                    if decisions is not None:
                        decisions.append({'path': str(path), 'allocated_bytes': size,
                                          'action': 'removed' if apply else 'eligible',
                                          'purpose': 'Hash-verified duplicate release working copy',
                                          'recovery': str(preserved), 'receipt': str(receipt_path)})
                    removed += 1
                    allocated += size
                    emit(f'{"REMOVE" if apply else "WOULD REMOVE"} duplicate-release-{kind} {path}: '
                         f'allocatedBytes={size}; expirySeconds={MAX_AGE}; owner=idle')
            except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
                emit(f'SKIP retained-release-or-unknown {run}: {error}; '
                     f'allocatedBytes={retention.metadata(run)[1]}')
    emit(f'{"Removed" if apply else "Eligible"} release duplicates: {removed}, '
         f'{allocated} allocated bytes ({allocated / 1024**3:.2f} GiB).')
    return removed, allocated
