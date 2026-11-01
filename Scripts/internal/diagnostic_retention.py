"""Bounded retention for producer-sealed diagnostics, never arbitrary deliverables."""
from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import time

from internal.cli import write_json_atomic

DAY = 86400
BUDGET = 2 * 1024**3
MAX_AGE = 3 * DAY
MIN_AGE = DAY
LIMIT = 64
PROTECTED = re.compile(r"(?:^|/)(?:sources?|originals?|art|assets?|saves?|backups?|masters?|finals?|trailers?|testflight|release|exports|dsyms)(?:/|$)|\.(?:sqlite(?:-wal|-shm)?|save|db|mp4|mov|mkv|ipa|xcarchive|trace|swift|tsx?|jsx?|patch|diff)$", re.I)


def snapshot(root: Path) -> dict:
    """A changed member, keep/owner marker, link or unknown file protects the bundle."""
    if root.is_symlink():
        raise ValueError('Linked diagnostic root')
    rows = []
    total = newest = 0
    for base, dirs, files in os.walk(root, followlinks=False) if root.is_dir() else [(root.parent, [], [root.name])]:
        for name in dirs + files:
            item = Path(base) / name
            rel = str(item.relative_to(root)) if item != root else item.name
            info = item.lstat()
            if (item.is_symlink() or not (item.is_file() or item.is_dir())
                    or PROTECTED.search(rel) or name.endswith(('.retention-keep', '.retention-distributed', '.retention-owner.json', '.lock'))):
                raise ValueError('Protected or unknown diagnostic member')
            if len(rows) >= 50000:
                raise ValueError('Diagnostic inventory limit reached')
            rows.append([rel, info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns])
            if item.is_file():
                total += info.st_size
                newest = max(newest, info.st_mtime)
    return {'fingerprint': hashlib.sha256(json.dumps(sorted(rows)).encode()).hexdigest(),
            'bytes': total, 'newest': newest}


def classify(names: list[str]) -> dict[str, str]:
    result = {}
    for name in names:
        parts = Path(name).parts
        if PROTECTED.search(name):
            continue
        bundle = next((i for i, p in enumerate(parts) if p.endswith('.xcresult')), None)
        if bundle is not None:
            result[str(Path(*parts[:bundle + 1]))] = 'xcresult'
        elif name.endswith(('.log', '.jsonl')):
            result[name] = 'log'
        elif re.search(r'build-timing-baseline/(?:hosted/ci-test-artifact\.tar|(?:fast|default)-[0-9]+\.tar\.gz)$', name):
            result[name] = 'build-comparison'
    return result


def seal(base: Path, names: list[str], *, now: float | None = None, since: float = 0) -> dict:
    now = time.time() if now is None else now
    entries = []
    for name, kind in classify(names).items():
        item = base / name
        if name.startswith('/') or '..' in Path(name).parts:
            continue
        try:
            state = snapshot(item)
            if state['newest'] >= since and state['bytes']:
                entries.append({'path': name, 'kind': kind, 'sealedAt': now, **state})
        except (OSError, ValueError):
            pass
    return {'version': 1, 'entries': entries}


def expire(records: list[tuple[Path, dict]], boundary: Path, *, apply: bool = False,
           now: float | None = None, budget: int = BUDGET, inactive=None) -> list[dict]:
    from internal.output_retention import protection, process_snapshot, safe_path, lifecycle_guard
    now = time.time() if now is None else now
    if not math.isfinite(now) or not math.isfinite(budget) or budget < 1:
        raise ValueError('Diagnostic budget must be positive')
    if not records:
        return []
    processes = process_snapshot()
    candidates = []
    for base, record in records:
        if not isinstance(record, dict) or record.get('version') != 1 or not isinstance(record.get('entries'), list):
            continue
        for item in record['entries']:
            if not isinstance(item, dict):
                continue
            try:
                name = item['path']
                target = base / name
                if (not isinstance(name, str) or '..' in Path(name).parts or Path(name).is_absolute()
                        or classify([name]).get(name) != item['kind'] or not safe_path(target, boundary)
                        or protection(target, boundary, processes)):
                    continue
                current = snapshot(target)
                if any(current[k] != item[k] for k in current) or not isinstance(item['sealedAt'], (int, float)) or not math.isfinite(item['sealedAt']):
                    continue
                candidates.append({'path': target, 'base': base, 'item': item,
                                   'age': now - max(item['sealedAt'], current['newest'])})
            except (OSError, ValueError, KeyError, TypeError):
                continue
    total = sum(x['item']['bytes'] for x in candidates)
    latest = {}
    for candidate in candidates:
        kind = (candidate['item']['kind'], candidate['item'].get('status', 'unknown'))
        if kind not in latest or candidate['age'] < latest[kind]['age']:
            latest[kind] = candidate
    decisions = []
    for candidate in sorted(candidates, key=lambda x: -x['age']):
        if len(decisions) >= LIMIT:
            break
        item, target, age = candidate['item'], candidate['path'], candidate['age']
        if age < MIN_AGE or latest[(item['kind'], item.get('status', 'unknown'))] is candidate:
            continue
        if age < MAX_AGE and total <= budget:
            continue
        def is_inactive():
            if inactive is not None:
                return inactive(target)
            result = subprocess.run(['lsof', '-nP', *(['+D', str(target)] if target.is_dir() else ['--', str(target)])],
                                    capture_output=True, text=True, timeout=5)
            return result.returncode == 1 and not result.stdout and not result.stderr
        try:
            if not is_inactive():
                continue
            with lifecycle_guard(boundary, apply=apply) as admitted:
                if (not admitted or protection(target, boundary, process_snapshot())
                        or not is_inactive() or snapshot(target)['fingerprint'] != item['fingerprint']):
                    continue
                if apply:
                    from internal.output_retention import remove
                    remove(target)
            total -= item['bytes']
            decisions.append({'path': str(target), 'bytes': item['bytes'], 'action': 'removed' if apply else 'eligible'})
        except (OSError, ValueError, subprocess.SubprocessError):
            continue
    return decisions


def archived(source: Path, *, apply: bool = False, now: float | None = None) -> list[dict]:
    """Existing task-creation maintenance owns scheduling; active branches remain protected."""
    def git(*args):
        return subprocess.check_output(['git', '-C', str(source), *args], text=True, timeout=10).strip()
    common = Path(git('rev-parse', '--path-format=absolute', '--git-common-dir'))
    active = {line.removeprefix('branch refs/heads/') for line in git('worktree', 'list', '--porcelain').splitlines()
              if line.startswith('branch refs/heads/')}
    root = common / 'trinket-evidence/codex'
    records = []
    if root.is_symlink() or not root.is_dir():
        return []
    for branch in sorted(root.iterdir()):
        if branch.is_symlink() or not branch.is_dir() or 'codex/' + branch.name in active:
            continue
        for manifest in sorted(branch.glob('*/evidence.json')):
            try:
                if manifest.is_symlink() or manifest.parent.is_symlink():
                    continue
                data = json.loads(manifest.read_text())
                if data['branch'] != 'codex/' + branch.name:
                    continue
                if 'diagnostic_retention' in data:
                    records.append((manifest.parent / 'files', data['diagnostic_retention']))
            except (OSError, ValueError, KeyError, TypeError):
                continue
    return expire(records, common, apply=apply, now=now)


def seal_completed_results(base: Path, since: float) -> None:
    """Only artifacts written by the just-finished managed producer receive expiry."""
    record_path = base / '.retention-diagnostics.json'
    if record_path.is_symlink():
        return
    previous = {'version': 1, 'kind': 'trinket-generated-diagnostics', 'entries': []}
    if record_path.exists():
        try:
            previous = json.loads(record_path.read_text())
            if (not isinstance(previous, dict) or previous.get('version') != 1 or previous.get('kind') != 'trinket-generated-diagnostics'
                    or not isinstance(previous.get('entries'), list)):
                return
        except (OSError, ValueError, TypeError):
            return
    names = [str(p.relative_to(base)) for p in base.rglob('*') if p.is_file() and not p.is_symlink()]
    current = seal(base, names, since=since)
    merged = {entry['path']: entry for entry in previous['entries']
              if isinstance(entry, dict) and isinstance(entry.get('path'), str) and (base / entry['path']).exists()}
    merged.update({entry['path']: entry for entry in current['entries']})
    write_json_atomic(record_path, {**previous, 'entries': list(merged.values())})


def result_records(base: Path) -> list[tuple[Path, dict]]:
    """Per-invocation records avoid parallel reporters overwriting a shared seal."""
    records = []
    for file in base.glob('.retention-diagnostic*.json'):
        try:
            if file.is_symlink() or not file.is_file():
                continue
            record = json.loads(file.read_text())
            if isinstance(record, dict) and record.get('kind') == 'trinket-generated-diagnostics':
                records.append((base, record))
        except (OSError, ValueError):
            continue
    return records


def seal_invocation(result: Path, log: Path | None = None, *, root: Path | None = None, status: str = 'unknown') -> None:
    from internal.cli import ROOT
    from internal.output_retention import output_roots, safe_path
    root = ROOT if root is None else root
    result = Path(os.path.abspath(result))
    bases = [base for base in output_roots(root) if base.name == 'TestResults' and base in result.parents]
    if not bases:
        return
    base = max(bases, key=lambda p: len(p.parts))
    if not safe_path(result, root):
        return
    files = [p for p in result.rglob('*') if p.is_file()] if result.is_dir() else []
    for candidate in [log, result.with_suffix('.log')]:
        if candidate is not None:
            candidate = Path(os.path.abspath(candidate))
            if candidate.is_file() and safe_path(candidate, base):
                files.append(candidate)
    names = [str(p.relative_to(base)) for p in files if p.is_relative_to(base)]
    record = seal(base, names)
    if not record['entries']:
        return
    for entry in record['entries']:
        entry['status'] = status if status in ('passed', 'failed') else 'unknown'
    key = hashlib.sha256(str(result.relative_to(base)).encode()).hexdigest()
    target = base / ('.retention-diagnostic-' + key + '.json')
    if target.is_symlink():
        return
    if target.exists():
        try:
            previous = json.loads(target.read_text())
            if not isinstance(previous, dict) or previous.get('kind') != 'trinket-generated-diagnostics':
                return
        except (OSError, ValueError):
            return
    write_json_atomic(target, {**record, 'kind': 'trinket-generated-diagnostics'})
