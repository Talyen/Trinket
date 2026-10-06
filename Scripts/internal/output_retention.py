"""One-day retention for known disposable outputs; build/release state is excluded."""

from __future__ import annotations

from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

from internal.cli import write_json_atomic

OWNER = '.retention-owner.json'
KEEP = '.retention-keep'
RESULT_NAMES = ('TestResults', 'PerformanceResults', 'Logs', 'HandoffResults',
                'DocumentationResults', 'ScriptTestResults', 'TestResults-artifact', 'GateResults-artifact', 'AgentEvaluationResults')
EXPERIMENTS = ('cpu-optimization-compile', 'BalanceSweepRefactor', 'LabyrinthFloorHostTests')


def retention_seconds() -> float:
    hours = float(os.environ.get('TRINKET_OUTPUT_MAX_AGE_HOURS', '24'))
    if not 0 < hours < float('inf'):
        raise ValueError('TRINKET_OUTPUT_MAX_AGE_HOURS must be finite and positive')
    return hours * 3600


def marker(path: Path, name: str) -> Path:
    return path / name if path.is_dir() else path.with_name(path.name + name)


def safe_path(path: Path, boundary: Path) -> bool:
    """Reject symlinks at every level, including a replaced output root."""
    path = Path(os.path.abspath(path))
    boundary = Path(os.path.abspath(boundary))
    resolved_boundary = boundary.resolve()
    if '..' in path.parts or not path.resolve().is_relative_to(resolved_boundary):
        return False
    return not any(parent.is_symlink() for parent in (path, *path.parents)
                   if parent.resolve().is_relative_to(resolved_boundary))


def output_roots(root: Path) -> list[Path]:
    derived = root / '.DerivedData'
    tenants = [derived, derived / 'Device']
    for parent in (derived / 'runs', derived / 'packages'):
        if safe_path(parent, root) and parent.is_dir():
            tenants.extend(p for p in parent.iterdir() if p.is_dir() and not p.is_symlink())
    roots = [tenant / name for tenant in tenants for name in RESULT_NAMES]
    roots += [root / 'BalanceSweepReports', root / 'PlaythroughReports', derived / 'testflight/commands']
    # Deployment receipts, signed archives, and symbols are operational state.
    # Only plain command logs in each release run are disposable.
    return roots


def managed_path(path: Path, root: Path) -> bool:
    if not safe_path(path, root):
        return False
    path, root = path.resolve(), root.resolve()
    release_log = path.suffix == '.log' and path.parent.parent == root / '.DerivedData/testflight'
    return release_log or any(path == base or path.is_relative_to(base) for base in output_roots(root))


def process_snapshot() -> dict[int, tuple[str, str]]:
    result = subprocess.run(['ps', '-axo', 'pid=,lstart=,command='], capture_output=True,
                            text=True, check=True, timeout=10)
    processes = {}
    for line in result.stdout.splitlines():
        fields = line.split(None, 6)
        if not line.strip():
            continue
        if len(fields) != 7 or not fields[0].isdigit():
            raise ValueError('incomplete process snapshot; refusing cleanup')
        processes[int(fields[0])] = (' '.join(fields[1:6]), fields[6])
    if not processes:
        raise ValueError('empty process snapshot; refusing cleanup')
    return processes


def protection(path: Path, root: Path, processes: dict[int, tuple[str, str]]) -> str:
    if not safe_path(path, root):
        return 'symlink or escaping path'
    original_path = str(path)
    path, root = path.resolve(), root.resolve()
    ancestors = [path, *[p for p in path.parents if p.is_relative_to(root)]]
    controls = [(marker(p, KEEP), marker(p, OWNER)) for p in ancestors]
    if path.is_dir():
        for base, dirs, files in os.walk(path, followlinks=False):
            if any((Path(base) / name).is_symlink() for name in files
                   if name.endswith((OWNER, KEEP))):
                return 'symlink retention control'
            # rmtree unlinks contained symlinks; neither walking nor deletion
            # follows them into source, caches, or another checkout.
            if any(name.endswith(KEEP) for name in files):
                return 'explicitly kept'
            controls.append((Path(base) / KEEP, Path(base) / OWNER))
            controls.extend((Path(base) / KEEP, Path(base) / name) for name in files if name.endswith(OWNER))
    for keep, owner in controls:
        if keep.is_symlink() or owner.is_symlink():
            return 'symlink retention control'
        if keep.exists():
            return 'explicitly kept'
        if owner.exists():
            try:
                identity = json.loads(owner.read_text())
                pid, started = identity['pid'], identity['started']
                if type(pid) is not int or pid <= 0 or not isinstance(started, str) or not started.strip():
                    return 'unknown owner'
                if pid in processes and processes[pid][0] == started:
                    return f'active owner {pid}'
            except (OSError, ValueError, KeyError, TypeError):
                return 'unknown owner'
    # Older runs predate owner markers. Never expire a path named by a live job.
    for pid, (_, command) in processes.items():
        relative = str(path.relative_to(root))
        if pid != os.getpid() and (original_path in command or str(path) in command or relative in command):
            return f'active process {pid}'
    # Existing tenant slots and directory locks remain authoritative; PID reuse
    # conservatively preserves output rather than reclaiming a foreign job.
    derived = root / '.DerivedData'
    slots = []
    for directory in (derived / '.active-sim', derived / '.active-ui'):
        if safe_path(directory, root) and directory.is_dir():
            slots.extend(p for p in directory.glob("*.slot") if p.is_file())
    for lock in (derived / '.performance.lock', derived / '.generate.lock', derived / 'testflight/.deploy.lock'):
        if lock.exists():
            slots.append(lock / 'pid')
    for slot in slots:
        try:
            pid = int(slot.read_text().split()[0])
        except (OSError, ValueError, IndexError):
            return 'unknown lease or lock owner'
        if pid in processes and path.is_relative_to(derived):
            return f'active lease or lock {pid}'
    return ''


def metadata(path: Path) -> tuple[float, int]:
    """Newest data write and allocated bytes; never follow directory symlinks."""
    stat = path.lstat()
    newest, size = stat.st_mtime, stat.st_blocks * 512
    if path.is_dir():
        for base, dirs, files in os.walk(path, followlinks=False):
            for name in [*dirs, *files]:
                if name in {OWNER, KEEP}:
                    continue
                child = Path(base) / name
                try:
                    info = child.lstat()
                except FileNotFoundError:
                    continue
                newest = max(newest, info.st_mtime)
                size += info.st_blocks * 512
    return newest, size


def remove(path: Path) -> None:
    if path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink(missing_ok=True)
    for name in (OWNER, KEEP):
        path.with_name(path.name + name).unlink(missing_ok=True)


def timestamp(value: object, fallback: float) -> float:
    try:
        when = datetime.fromisoformat(value) if isinstance(value, str) else None
        return when.timestamp() if when and when.tzinfo else fallback
    except ValueError:
        return fallback


def timing_lines(lines: list[str], modified: float, now: float) -> list[str]:
    retained = []
    cutoff = now - retention_seconds()
    for line in lines:
        try:
            entry = json.loads(line)
            if not isinstance(entry, dict):
                continue
            if 'recorded_at' in entry and not isinstance(entry['recorded_at'], str):
                continue
            recorded = timestamp(entry.get('recorded_at'), modified)
            if recorded <= cutoff:
                continue
            # Date legacy entries once before a newer append refreshes file mtime.
            entry['recorded_at'] = datetime.fromtimestamp(recorded, timezone.utc).isoformat()
            retained.append(json.dumps(entry, separators=(',', ':')))
        except (ValueError, TypeError):
            continue
    return retained


def is_kept(path: Path) -> bool:
    return marker(path, KEEP).exists() or any((parent / KEEP).exists() for parent in path.parents)


def read_timing(path: Path) -> list[str]:
    if not path.exists():
        return []
    with path.open() as stream:
        fcntl.flock(stream, fcntl.LOCK_SH)
        lines = stream.read().splitlines()
        return lines if is_kept(path) else timing_lines(lines, os.fstat(stream.fileno()).st_mtime, time.time())


def update_timing(path: Path, *, entry: dict | None = None, maximum: int | None = None,
                  apply: bool = True, now: float | None = None) -> int:
    now = time.time() if now is None else now
    if not path.exists() and entry is None:
        return 0
    if entry is not None:
        path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a+' if apply else 'r') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX if apply else fcntl.LOCK_SH)
        stream.seek(0)
        previous = stream.read().splitlines()
        kept = previous if is_kept(path) else timing_lines(previous, os.fstat(stream.fileno()).st_mtime, now)
        removed = len(previous) - len(kept)
        if entry is not None:
            kept.append(json.dumps(entry, separators=(',', ':')))
        if maximum is not None:
            kept = kept[-maximum:]
        if apply:
            stream.seek(0)
            stream.truncate()
            stream.write('\n'.join(kept) + ('\n' if kept else ''))
        return removed


def begin(path: Path, root: Path, pid: int) -> None:
    if not managed_path(path, root):
        raise ValueError('owner markers require a known repository output path')
    processes = process_snapshot()
    if pid not in processes:
        raise ValueError('output owner is not running')
    owner = marker(path, OWNER)
    if owner.exists():
        identity = json.loads(owner.read_text())
        if type(identity.get('pid')) is not int or not isinstance(identity.get('started'), str):
            raise ValueError('output already has an unknown owner')
        if processes.get(identity['pid'], ('', ''))[0] == identity['started']:
            raise ValueError('output already has a live owner')
    write_json_atomic(owner, {'pid': pid, 'started': processes[pid][0]})


def finish(path: Path, root: Path, pid: int, status: int, *, comparison: bool = False) -> None:
    if not managed_path(path, root):
        raise ValueError('finish requires a known repository output path')
    owner = marker(path, OWNER)
    processes = dict(process_snapshot())
    identity = json.loads(owner.read_text())
    if identity != {'pid': pid, 'started': processes.get(pid, ('', ''))[0]}:
        raise ValueError('output belongs to another invocation')
    owner.unlink()
    processes.pop(pid, None)
    if status == 0 and not comparison and path not in output_roots(root) and not protection(path, root, processes):
        remove(path)


def cleanup(root: Path, *, apply: bool, experiments: bool = False,
            now: float | None = None, receipts_dir: Path | None = None, verbose: bool = True) -> tuple[int, int]:
    now = time.time() if now is None else now
    emit = print if verbose else lambda *args: None
    processes = process_snapshot()
    paths = []
    for base in output_roots(root):
        if safe_path(base, root) and base.is_dir():
            paths.extend(disposable_entries(base))
        elif base.is_symlink():
            emit(f'SKIP {base}: symlink')
    releases = root / '.DerivedData/testflight'
    if safe_path(releases, root) and releases.is_dir():
        for run in releases.iterdir():
            if safe_path(run, root) and run.is_dir() and run.name != 'commands':
                paths.extend(run.glob('*.log'))
    lifetime = root / '.DerivedData/.active-sim'
    if safe_path(lifetime, root) and lifetime.is_dir():
        paths.extend(lifetime.glob('*.lifetime.log'))
    if experiments:
        paths.extend(root / '.DerivedData' / name for name in EXPERIMENTS)
    temporary = receipts_dir or Path(tempfile.gettempdir())
    for path in temporary.glob('trinket-agent-*.json'):
        if not safe_path(path, temporary):
            continue
        try:
            if json.loads(path.read_text()).get('root') == str(root.resolve()):
                paths.append(path)
        except (OSError, ValueError, AttributeError):
            continue
    inside = [p for p in paths if p.is_relative_to(root)]
    outside = [p for p in paths if not p.is_relative_to(root)]
    immediate = {root / '.DerivedData' / name for name in EXPERIMENTS} if experiments else set()
    a, b = expire_paths(inside, root, apply=apply, now=now, processes=processes, verbose=verbose, immediate=immediate)
    c, d = expire_paths(outside, temporary, apply=apply, now=now, processes=processes, verbose=verbose)
    emit(f'{"Removed" if apply else "Eligible"}: {a + c} outputs, {b + d} allocated bytes ({(b + d) / 1024**3:.2f} GiB).')
    return a + c, b + d


def expire_paths(paths: list[Path], boundary: Path, *, apply: bool, now: float | None = None,
                 processes: dict[int, tuple[str, str]] | None = None, verbose: bool = True,
                 immediate: set[Path] | None = None) -> tuple[int, int]:
    now = time.time() if now is None else now
    processes = process_snapshot() if processes is None else processes
    emit = print if verbose else lambda *args: None
    immediate = immediate or set()
    count = total = 0
    for path in sorted(set(paths)):
        if not path.exists() and not path.is_symlink():
            continue
        reason = protection(path, boundary, processes)
        if reason:
            emit(f'SKIP {path}: {reason}')
            continue
        if path.name in {'timing-log.jsonl', 'phase-timing.jsonl'}:
            removed = update_timing(path, apply=apply, now=now)
            if removed:
                emit(f'{"PRUNE" if apply else "WOULD PRUNE"} {path}: {removed} expired timing entries')
            continue
        try:
            modified, size = metadata(path)
        except FileNotFoundError:
            continue
        if path not in immediate and modified > now - retention_seconds():
            continue
        # Recheck before mutation: new keep controls or owners invalidate a candidate.
        if apply:
            reason = protection(path, boundary, process_snapshot())
            if reason:
                emit(f'SKIP {path}: {reason}')
                continue
        if path in immediate:
            opened = subprocess.run(['lsof', '-n', '-P', '+D', str(path)],
                                    capture_output=True, text=True, timeout=30)
            if opened.returncode != 1 or opened.stdout.strip() or opened.stderr.strip():
                emit(f'SKIP {path}: open files or unavailable open-file inventory')
                continue
        if apply:
            if not path.exists() or (path not in immediate and metadata(path)[0] > now - retention_seconds()):
                continue
            remove(path)
        count += 1
        total += size
        emit(f'{"REMOVE" if apply else "WOULD REMOVE"} {path}: {size} allocated bytes')
    return count, total


def disposable_entries(base: Path) -> list[Path]:
    paths = []
    for path in base.iterdir():
        if path.name.startswith('.') or path.name.endswith((OWNER, KEEP)):
            continue
        if path.name == 'raw' and path.is_dir() and not path.is_symlink():
            paths.extend(path.iterdir())
        else:
            paths.append(path)
    return paths


def expire_results(base: Path) -> tuple[int, int]:
    """Explicit TestResults callers may live outside the checkout (CI/fixtures)."""
    from internal.cli import ROOT
    if base.name != 'TestResults' or not safe_path(base, base) or not base.is_dir():
        raise ValueError('expiry requires an explicit nonsymlink TestResults directory')
    boundary = ROOT if base.is_relative_to(ROOT) else base
    return expire_paths(disposable_entries(base), boundary, apply=True)
