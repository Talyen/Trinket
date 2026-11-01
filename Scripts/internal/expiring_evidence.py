"""Expire classified visual media and device-profile payloads after 24 hours."""
from __future__ import annotations

from contextlib import contextmanager
import fcntl
import json
from itertools import chain
import os
from pathlib import Path
import re
import subprocess
import time

from internal import build_symbols, output_retention as retention
from internal.cli import legacy_runtime_owner

AGE = 24 * 3600
VISUAL = {'.png', '.jpg', '.jpeg', '.heic', '.gif', '.mov', '.mp4'}
VISUAL_CONTEXT = ('inspection', 'screenshot', 'visual-review', 'visual-evidence', 'visualevidence', 'capture', 'review-frames')


@contextmanager
def evidence_lock(common: Path, apply: bool):
    if not apply:
        yield True
        return
    with (common / 'trinket-integration.lock').open('a+') as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            yield False
            return
        yield True


def active_branches(root: Path) -> set[str]:
    output = subprocess.check_output(['git', '-C', str(root), 'worktree', 'list', '--porcelain', '-z'], timeout=30)
    return {os.fsdecode(field[len(b'branch refs/heads/'):]) for field in output.split(b'\0')
            if field.startswith(b'branch refs/heads/')}


def shared_leases_busy(root: Path) -> bool:
    if legacy_runtime_owner(root, ('.active-sim', '.active-ui', '.active-build', '.simulator-cleanup.lock')) is not None:
        return True
    for name in ('.active-sim', '.active-ui', '.active-build'):
        state = root / '.DerivedData' / name
        if state.is_symlink():
            return True
        for slot in state.glob('*.slot'):
            if slot.is_symlink():
                return True
            try:
                pid = int(slot.read_text().split()[0])
            except (OSError, ValueError, IndexError):
                return True
            if retention.process_alive(pid):
                return True
    return False


def profile_candidates(artifact_root: Path):
    profiles = artifact_root / 'profiles'
    if profiles.is_symlink() or not profiles.is_dir():
        return
    seen = set()
    for session in sorted(profiles.glob('device-*')):
        if (session.is_symlink() or not session.is_dir() or (session / 'result.json').is_symlink()
                or not (session / 'result.json').is_file()):
            continue
        for path in sorted(session.iterdir()):
            if path.name in {'Binaries', 'symbols', 'exports'} or path.suffix in {'.trace', '.xml'}:
                seen.add(path)
                yield path, session, profiles
    for path in trace_bundles(profiles):
        if path not in seen:
            yield path, path, profiles


def is_visual_evidence(path: Path) -> bool:
    return path.suffix.lower() in VISUAL and any(term in str(path).lower() for term in VISUAL_CONTEXT)


def snapshot_candidates(common: Path, active: set[str], *, traces_only: bool):
    evidence = common / 'trinket-evidence/codex'
    if evidence.is_symlink() or evidence.parent.is_symlink() or not evidence.is_dir():
        return
    for branch in sorted(evidence.iterdir()):
        if branch.is_symlink() or not branch.is_dir() or not re.fullmatch(r'[a-z0-9][a-z0-9_-]{0,63}', branch.name) or 'codex/' + branch.name in active:
            continue
        for manifest in sorted(branch.glob('*/evidence.json')):
            snapshot = manifest.parent
            if manifest.is_symlink() or snapshot.is_symlink():
                continue
            try:
                saved = json.loads(manifest.read_text())
                if saved['branch'] != 'codex/' + branch.name or not isinstance(saved['files'], list):
                    continue
                traces = set()
                visuals = []
                for name in saved['files']:
                    if not isinstance(name, str):
                        continue
                    relative = Path(name)
                    if relative.is_absolute() or '..' in relative.parts:
                        continue
                    parts = relative.parts
                    index = next((i for i, part in enumerate(parts) if part.endswith('.trace')), None)
                    if index is not None:
                        if not any(part.endswith(('.xcresult', '.xcarchive')) for part in parts[:index]):
                            traces.add(Path(*parts[:index + 1]))
                    elif (not any(part.endswith(('.xcresult', '.xcarchive', '.app', '.dSYM')) for part in parts)
                          and is_visual_evidence(relative)):
                        visuals.append(relative)
                for relative in (sorted(traces) if traces_only else visuals):
                    yield snapshot / 'files' / relative, manifest, evidence
            except (OSError, ValueError, KeyError, TypeError):
                continue


def trace_bundles(base: Path):
    if base.is_symlink() or not base.is_dir():
        return
    for directory, folders, files in os.walk(base, followlinks=False):
        for name in list(folders):
            path = Path(directory) / name
            if path.is_symlink() or name.endswith(('.xcresult', '.xcarchive', '.app', '.dSYM')):
                folders.remove(name)
            elif name.endswith('.trace'):
                folders.remove(name)
                yield path
        for name in files:
            if name.endswith('.trace'):
                yield Path(directory) / name


def local_trace_candidates(root: Path):
    for base in (root / '.DerivedData/PerformanceResults', root / '.DerivedData/Deliverables'):
        if retention.safe_path(base, root):
            for path in trace_bundles(base) or ():
                yield path, path, root


def local_visual_candidates(root: Path):
    for base in (root / '.DerivedData/VisualEvidence', root / '.DerivedData/Deliverables'):
        if not retention.safe_path(base, root) or not base.is_dir():
            continue
        for directory, folders, files in os.walk(base, followlinks=False):
            folders[:] = [name for name in folders if not name.endswith(('.xcresult', '.xcarchive', '.trace', '.app', '.dSYM'))
                           and not (Path(directory) / name).is_symlink()]
            for name in files:
                path = Path(directory) / name
                if is_visual_evidence(path.relative_to(root)):
                    yield path, root


def removable(path: Path, owner: Path, boundary: Path, now: float, processes: dict, *, check_open: bool = True) -> tuple[bool, int]:
    if not path.exists() or not retention.safe_path(path, boundary) or not retention.safe_path(owner, boundary):
        return False, 0
    if retention.protection(owner, boundary, processes, scoped=True) or retention.protection(path, boundary, processes, scoped=True):
        return False, 0
    modified, size = retention.metadata(path)
    owner_time = (owner / 'result.json').stat().st_mtime if owner.is_dir() and owner != path else owner.stat().st_mtime
    if max(modified, owner_time) > now - AGE:
        return False, 0
    return (not check_open or unopened([path])), size


def unopened(paths: list[Path]) -> bool:
    if not paths:
        return False
    args = ['+D', str(paths[0])] if len(paths) == 1 and paths[0].is_dir() else ['--', *map(str, paths)]
    result = subprocess.run(['lsof', '-n', '-P', *args], capture_output=True, text=True, timeout=30)
    return result.returncode == 1 and not result.stdout.strip() and not result.stderr.strip()


def identity(path: Path) -> tuple[int, int, int, int, int]:
    value = path.lstat()
    return value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns, value.st_ctime_ns


def unchanged(item: tuple, now: float, processes: dict) -> bool:
    path, manifest, boundary, _, original = item
    try:
        return (removable(path, manifest, boundary, now, processes, check_open=False)[0]
                and identity(path) == original)
    except OSError:
        return False


def snapshot_batches(candidates):
    batch = []
    key = None
    for item in candidates:
        path, manifest, _ = item
        next_key = (manifest, path.parent) if not path.is_dir() else None
        if batch and (next_key != key or next_key is None or len(batch) >= 32):
            yield batch
            batch = []
        batch.append(item)
        key = next_key
        if next_key is None:
            yield batch
            batch = []
    if batch:
        yield batch


def cleanup(root: Path, common: Path, *, apply: bool, now: float | None = None,
            artifact_root: Path | None = None, limit: int = 32) -> tuple[int, int]:
    now = time.time() if now is None else now
    artifact_root = artifact_root or build_symbols.artifact_root()
    count = total = 0
    # Producer leases cover external profile paths; refuse ambiguous owners globally.
    with retention.lifecycle_guard(root, apply=apply) as admitted:
        if admitted and not shared_leases_busy(root):
            processes = retention.process_snapshot()
            processes.pop(os.getpid(), None)
            for path, owner, boundary in local_trace_candidates(root):
                ok, size = removable(path, owner, boundary, now, processes)
                if not ok:
                    continue
                if apply:
                    if shared_leases_busy(root) or not removable(path, owner, boundary, now, retention.process_snapshot())[0]:
                        continue
                    retention.remove(path)
                print(f'{"REMOVE" if apply else "WOULD REMOVE"} expired profile {path}: {size} allocated bytes')
                count += 1
                total += size
                if count >= limit:
                    return count, total
            for path, boundary in local_visual_candidates(root):
                # The file is its own age anchor; parent keep/owner markers still apply.
                ok, size = removable(path, path, boundary, now, processes)
                if not ok:
                    continue
                if apply:
                    if shared_leases_busy(root) or not removable(path, path, boundary, now, retention.process_snapshot())[0]:
                        continue
                    retention.remove(path)
                print(f'{"REMOVE" if apply else "WOULD REMOVE"} expired visual {path}: {size} allocated bytes')
                count += 1
                total += size
                if count >= limit:
                    return count, total
            for path, owner, boundary in profile_candidates(artifact_root) or ():
                ok, size = removable(path, owner, boundary, now, processes)
                if not ok:
                    continue
                if apply:
                    if shared_leases_busy(root) or not removable(path, owner, boundary, now, retention.process_snapshot())[0]:
                        continue
                    retention.remove(path)
                print(f'{"REMOVE" if apply else "WOULD REMOVE"} expired profile {path}: {size} allocated bytes')
                count += 1
                total += size
                if count >= limit:
                    return count, total
        else:
            print('SKIP profile evidence: active or unknown producer lease')
    # Group neighboring regular files; one open-file query protects every file
    # in a bounded batch. Native trace bundles retain their directory check.
    active = active_branches(root)
    processes = retention.process_snapshot()
    processes.pop(os.getpid(), None)
    candidates = chain(snapshot_candidates(common, active, traces_only=True) or (),
                       snapshot_candidates(common, active, traces_only=False) or ())
    for batch in snapshot_batches(candidates):
        if count >= limit:
            break
        eligible = []
        for path, manifest, boundary in batch:
            ok, size = removable(path, manifest, boundary, now, processes, check_open=False)
            if ok:
                eligible.append((path, manifest, boundary, size, identity(path)))
                if len(eligible) >= limit - count:
                    break
        if not eligible or not unopened([item[0] for item in eligible]):
            continue
        if apply:
            with evidence_lock(common, True) as admitted:
                if not admitted:
                    print('SKIP visual evidence: integration lock busy')
                    break
                branch = 'codex/' + eligible[0][1].parent.parent.name
                if branch in active_branches(root):
                    continue
                current = retention.process_snapshot()
                eligible = [item for item in eligible if unchanged(item, now, current)]
                if not eligible or not unopened([item[0] for item in eligible]):
                    continue
                manifest = eligible[0][1]
                journal = manifest.parent.parent / ('profile-expiry.jsonl' if eligible[0][0].suffix == '.trace' else 'visual-expiry.jsonl')
                if journal.is_symlink():
                    continue
                with journal.open('a') as stream:
                    for path, _, _, _, _ in eligible:
                        stream.write(json.dumps({'snapshot': manifest.parent.name, 'file': str(path.relative_to(manifest.parent / 'files')), 'retired_at': now}) + '\n')
                    stream.flush()
                    os.fsync(stream.fileno())
                if branch in active_branches(root):
                    continue
                current = retention.process_snapshot()
                eligible = [item for item in eligible if unchanged(item, now, current)]
                if not eligible or not unopened([item[0] for item in eligible]):
                    continue
                for path, _, _, _, _ in eligible:
                    retention.remove(path)
        for path, _, _, size, _ in eligible:
            kind = 'profile' if path.suffix == '.trace' else 'visual'
            print(f'{"REMOVE" if apply else "WOULD REMOVE"} expired {kind} {path}: {size} allocated bytes')
            count += 1
            total += size
    print(f'{"Removed" if apply else "Eligible"} evidence payloads: {count}, {total} allocated bytes (APFS extents may be shared).')
    return count, total
