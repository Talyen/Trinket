#!/usr/bin/env python3
"""Serialize verified, local-only task landings into the primary main checkout."""

from __future__ import annotations

import fcntl
from contextlib import contextmanager
import os
import re
from pathlib import Path
import subprocess
import sys
import json
import tempfile
import shutil
import hashlib
import ctypes
import time
from datetime import datetime, timezone


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).rstrip("\n")


def clean(root: Path) -> None:
    if git(root, "status", "--porcelain", "--untracked-files=all"):
        raise RuntimeError(f"Dirty checkout preserved: {root}. Commit task work before integrating; never stash unrelated work.")
    for state in ("rebase-merge", "rebase-apply", "MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "BISECT_START"):
        if Path(git(root, "rev-parse", "--path-format=absolute", "--git-path", state)).exists():
            raise RuntimeError(f"Finish the existing Git operation in {root} first.")


def preserve_ignored(root: Path, incoming: str) -> None:
    tracked = set(git(root, "ls-tree", "-r", "--name-only", "-z", incoming).rstrip("\0").split("\0"))
    directories = {str(parent) for name in tracked for parent in Path(name).parents}
    ignored = git(root, "ls-files", "--others", "--ignored", "--exclude-standard", "-z")
    for name in filter(None, ignored.rstrip("\0").split("\0")):
        if name in tracked or name in directories or any(str(parent) in tracked for parent in Path(name).parents):
            raise RuntimeError(f"Ignored file would be overwritten in {root}: {name}. Preserve it before integrating.")


def evidence_directory(source: Path) -> Path:
    common = Path(git(source, 'rev-parse', '--path-format=absolute', '--git-common-dir')).resolve()
    branch = git(source, 'branch', '--show-current')
    if not branch.startswith('codex/'):
        raise RuntimeError('Task evidence requires a codex/ task branch.')
    destination = common / 'trinket-evidence' / branch
    if not destination.resolve().is_relative_to(common):
        raise RuntimeError('Evidence directory must remain inside the shared Git directory.')
    if any(parent.is_symlink() for parent in (destination, *destination.parents) if parent.is_relative_to(common)):
        raise RuntimeError('Evidence directory cannot follow symlinks.')
    destination.mkdir(parents=True, exist_ok=True)
    return destination


def copy_evidence(source: Path, target: Path) -> None:
    """Use independent copy-on-write files where supported, then fall back to copying."""
    if sys.platform == 'darwin':
        clone = getattr(ctypes.CDLL(None, use_errno=True), 'clonefile', None)
        if clone is not None:
            clone.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint32]
            clone.restype = ctypes.c_int
            if clone(os.fsencode(source), os.fsencode(target), 1) == 0:
                shutil.copystat(source, target, follow_symlinks=False)
                return
            if target.exists() or target.is_symlink():
                raise RuntimeError(f'Failed evidence clone left a destination: {target}')
    shutil.copy2(source, target, follow_symlinks=False)


def routine_report(path: Path) -> bool:
    """Recognize only successful static handoff reports, never visual or release proof."""
    if not re.fullmatch(r'(auto|static)-[0-9a-f]{32}\.json', path.name):
        return False
    try:
        data = json.loads(path.read_text())
        checks = data['checks']
        return (data['version'] == 2 and data['route'] in ('auto', 'static')
                and data['exit_status'] == 0 and data['local_state'] == 'checks passed'
                and isinstance(checks, list) and bool(checks)
                and all(isinstance(check, dict)
                        and re.fullmatch(r'(docs|docs-final|scripts|scripts-syntax|cheap-[0-9]+)', check.get('id', ''))
                        and check.get('outcome') in ('passed', 'deferred to CI') for check in checks))
    except (OSError, ValueError, KeyError, TypeError):
        return False


def preserve_evidence(source: Path, names: list[str], *, routine: bool = False) -> Path:
    """Copy explicit deliverables before cleanup, without following symlinks."""
    paths = []
    for name in names:
        path = Path(os.path.abspath(source / name))
        if not path.is_relative_to(source) or not path.exists():
            raise RuntimeError(f'Evidence must exist inside the task checkout: {name}')
        if any(parent.is_symlink() for parent in (path, *path.parents) if parent.is_relative_to(source)):
            raise RuntimeError(f'Evidence cannot follow symlinks: {name}')
        files = [path, *path.rglob('*')] if path.is_dir() else [path]
        if any(item.is_symlink() or not (item.is_file() or item.is_dir()) for item in files):
            raise RuntimeError(f'Evidence contains a symlink or special file: {name}')
        paths.extend(item for item in files if item.is_file())
    destination = evidence_directory(source)
    if not paths:
        return destination
    head = git(source, 'rev-parse', 'HEAD')
    def hashes(items):
        result = {}
        for item in sorted(set(items)):
            value = hashlib.sha256()
            with item.open('rb') as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    value.update(block)
            result[str(item.relative_to(source))] = value.hexdigest()
        return result
    expected = hashes(paths)
    def source_unchanged():
        current = []
        for name in names:
            path = Path(os.path.abspath(source / name))
            items = [path, *path.rglob('*')] if path.is_dir() else [path]
            if any(item.is_symlink() or not (item.is_dir() or item.is_file()) for item in items):
                return False
            current.extend(item for item in items if item.is_file())
        return hashes(current) == expected
    # Legacy snapshots remain valid candidates: compare their actual bytes,
    # rather than trusting a stored digest or creating mutable hard links.
    for candidate in sorted(destination.glob(head[:12] + '-*')):
        files_root = candidate / 'files'
        if candidate.is_symlink() or files_root.is_symlink() or not files_root.is_dir():
            continue
        files = list(files_root.rglob('*'))
        if any(item.is_symlink() or not (item.is_dir() or item.is_file()) for item in files):
            continue
        actual = {}
        for item in files:
            if item.is_file():
                with item.open('rb') as stream:
                    value = hashlib.sha256()
                    for block in iter(lambda: stream.read(1024 * 1024), b''):
                        value.update(block)
                actual[str(item.relative_to(files_root))] = value.hexdigest()
        if actual == expected:
            if not source_unchanged():
                raise RuntimeError('Evidence changed during preservation; original files retained')
            if not routine:
                # An explicit evidence request must never inherit automatic expiry.
                keep = candidate / '.retention-keep'
                if keep.is_symlink():
                    raise RuntimeError('Evidence keep marker cannot follow a symlink')
                keep.touch()
            record_preservation(destination, candidate, head)
            print(f'Reused verified task evidence: {candidate}')
            return candidate
    saved = Path(tempfile.mkdtemp(prefix=head[:12] + '-', dir=destination))
    for path in sorted(set(paths)):
        target = saved / 'files' / path.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        copy_evidence(path, target)
        with target.open('rb') as stream:
            value = hashlib.sha256()
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                value.update(block)
        if value.hexdigest() != expected[str(path.relative_to(source))]:
            raise RuntimeError(f'Evidence copy verification failed: {path}')
    if not source_unchanged():
        raise RuntimeError('Evidence changed during preservation; original files retained')
    reports = {name: digest for name, digest in expected.items()
               if routine and Path(name).parent == Path('.DerivedData/Deliverables/Verification')
               and routine_report(source / name)}
    (saved / 'evidence.json').write_text(json.dumps({
        'preserved_at_commit': head, 'branch': git(source, 'branch', '--show-current'),
        'files': [str(path.relative_to(source)) for path in sorted(set(paths))],
        'routine_reports': reports,
    }, indent=2) + '\n')
    record_preservation(destination, saved, head)
    print(f'Preserved task evidence: {saved}')
    return saved


def record_preservation(destination: Path, saved: Path, head: str) -> None:
    journal = destination / 'preservations.jsonl'
    if journal.is_symlink():
        raise RuntimeError('Evidence provenance cannot follow a symlink')
    with journal.open('a') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        stream.write(json.dumps({'snapshot': saved.name, 'commit': head,
                                'preserved_at': datetime.now(timezone.utc).isoformat()}) + '\n')


def preserve_default_evidence(source: Path) -> Path | None:
    deliverables = source / '.DerivedData/Deliverables'
    if deliverables.exists() or deliverables.is_symlink():
        return preserve_evidence(source, ['.DerivedData/Deliverables'], routine=True)


def save_task_report(source: Path, base: str, head: str, paths: list[str], *, landed: bool = False) -> Path:
    from internal.cli import write_json_atomic
    directory = source / '.DerivedData/Deliverables'
    if any(path.is_symlink() for path in (directory, *directory.parents) if path.is_relative_to(source)):
        raise RuntimeError('Task deliverables cannot follow symlinks')
    directory.mkdir(parents=True, exist_ok=True)
    report = directory / 'task-report.json'
    if report.is_symlink():
        raise RuntimeError('Task report cannot follow symlinks')
    write_json_atomic(report, {
        'version': 1, 'branch': git(source, 'branch', '--show-current'),
        'static_verified_commit': head, 'verified_against_main': base, 'changed_paths': paths,
        'verification_reports': sorted(str(path.relative_to(source)) for path in (directory / 'Verification').glob('*.json')),
        'verification_report_retention': 'Routine successful static reports may expire seven days after task cleanup.',
        'completion_state': 'locally integrated; hosted verification pending' if landed else 'local checks passed; landing pending',
        'limitations': 'Landing checks are static; compiled and visual results are in the referenced reports. Hosted evidence requires an authorized push.',
    })
    return report


def remove_integrated_worktree(source: Path, target: Path, branch: str, head: str, *, main_head: str | None = None) -> None:
    records = git(target, "worktree", "list", "--porcelain", "-z").split("\0\0")
    record = next((r.split("\0") for r in records if "worktree " + str(source) in r.split("\0")), [])
    if (source == target or source.is_symlink() or "branch refs/heads/" + branch not in record
            or any(field.startswith(("locked", "prunable")) for field in record)):
        raise RuntimeError("Task worktree registration changed or is locked")
    clean(source)
    if (git(source, "branch", "--show-current") != branch
            or git(source, "rev-parse", "HEAD") != head or git(target, "rev-parse", "main") != (main_head or head)):
        raise RuntimeError("Task or main changed after integration")
    if any(line.startswith("160000 ") for line in git(source, "ls-files", "--stage").splitlines()):
        raise RuntimeError("Submodule worktree preserved")
    archive_root = Path(os.environ.get("CODEX_WORKTREE_ARCHIVE_ROOT", Path.home() / ".codex/worktree-archives/Trinket")).resolve()
    common = Path(git(target, "rev-parse", "--path-format=absolute", "--git-common-dir")).resolve()
    if any(archive_root == p or archive_root.is_relative_to(p) for p in (source, target, common)):
        raise RuntimeError("Recovery directory must be outside the repository and task checkout")
    archive_root.mkdir(parents=True, exist_ok=True, mode=0o700)
    recovery = Path(tempfile.mkdtemp(prefix=branch.replace('/', '-') + '-', dir=archive_root))
    (recovery / 'recovery.json').write_text(json.dumps(dict(main=str(target), task=str(source), branch=branch, head=head), indent=2))
    checkout = recovery / 'checkout'
    # Stage the checkout so failed unregistration can restore it. Delete only
    # after Git releases this registration; never prune peers or use --force.
    os.chdir(target)
    source.rename(checkout)
    try:
        subprocess.run(['git', '-C', str(target), 'worktree', 'remove', str(source)], check=True)
    except subprocess.CalledProcessError:
        if not source.exists():
            checkout.rename(source)
        raise
    (checkout / '.git').unlink()
    shutil.rmtree(recovery)
    print(f'Removed completed worktree {source}, including local-only files; retained branch {branch}.')

def checkout_context(source: Path) -> tuple[Path, Path]:
    common = Path(git(source, "rev-parse", "--path-format=absolute", "--git-common-dir"))
    # Git lists the primary checkout first; bare repositories are not landing targets.
    records = git(source, "worktree", "list", "--porcelain", "-z").split("\0\0")
    primary = records[0].split("\0")
    if "bare" in primary or not primary[0].startswith("worktree "):
        raise RuntimeError("A non-bare primary checkout on main is required.")
    target = Path(primary[0][len("worktree "):]).resolve()
    if source == target:
        raise RuntimeError("Run integration from the isolated task worktree, not the primary checkout.")
    return common, target


@contextmanager
def integration_lock(common: Path):
    # An OS-held lock releases on exit/crash. Never unlink this file: all callers
    # must lock the same inode, including callers in different linked worktrees.
    with (common / "trinket-integration.lock").open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("Integration busy. Retry later without messaging other chats.") from None
        yield


def cleanup(source: Path) -> None:
    """Retry only cleanup, including after main advances beyond the landed task."""
    common, target = checkout_context(source)
    with integration_lock(common):
        branch = git(source, 'branch', '--show-current')
        if not branch.startswith('codex/') or git(target, 'branch', '--show-current') != 'main':
            raise RuntimeError('Cleanup requires a codex/ task and a primary checkout on main')
        clean(source)
        head = git(source, 'rev-parse', 'HEAD')
        main_head = git(target, 'rev-parse', 'HEAD')
        subprocess.run(['git', '-C', str(source), 'merge-base', '--is-ancestor', head, main_head], check=True)
        preserve_default_evidence(source)
        evidence = evidence_directory(source)
        from internal.cli import write_json_atomic
        remove_integrated_worktree(source, target, branch, head, main_head=main_head)
        write_json_atomic(evidence / 'routine-completion.json', {
            'schema': 1, 'branch': branch, 'head': head,
            'completed_at': datetime.now(timezone.utc).isoformat(),
        })


def expire_routine_evidence(source: Path, *, now: float | None = None) -> int:
    """Expire classified reports only after task cleanup; unknown evidence stays put."""
    now = time.time() if now is None else now
    common = Path(git(source, 'rev-parse', '--path-format=absolute', '--git-common-dir')).resolve()
    root = common / 'trinket-evidence' / 'codex'
    if not root.is_dir() or root.is_symlink() or root.parent.is_symlink():
        return 0
    removed = 0
    def kept(path: Path) -> bool:
        return path.exists() or path.is_symlink()
    with integration_lock(common):
        records = git(source, 'worktree', 'list', '--porcelain', '-z').split('\0\0')
        active = {line[len('branch refs/heads/'):] for record in records for line in record.split('\0')
                  if line.startswith('branch refs/heads/')}
        for branch_dir in root.iterdir():
            if branch_dir.is_symlink() or not branch_dir.is_dir() or not re.fullmatch(r'[a-z0-9][a-z0-9_-]{0,63}', branch_dir.name):
                continue
            branch = 'codex/' + branch_dir.name
            completion = branch_dir / 'routine-completion.json'
            if branch in active or completion.is_symlink() or not completion.is_file():
                continue
            try:
                finished = json.loads(completion.read_text())
                stamp = datetime.fromisoformat(finished['completed_at'])
                head = finished['head']
                if (finished['schema'] != 1 or finished['branch'] != branch or stamp.tzinfo is None
                        or not re.fullmatch(r'[0-9a-f]{40}', head)
                        or max(stamp.timestamp(), completion.stat().st_mtime) > now - 7 * 86400):
                    continue
            except (OSError, ValueError, KeyError, TypeError):
                continue
            for snapshot in branch_dir.glob(head[:12] + '-*'):
                manifest = snapshot / 'evidence.json'
                if snapshot.is_symlink() or not snapshot.is_dir() or manifest.is_symlink() or not manifest.is_file():
                    continue
                try:
                    saved = json.loads(manifest.read_text())
                    if saved['branch'] != branch or saved['preserved_at_commit'] != head or not isinstance(saved['routine_reports'], dict):
                        continue
                    for name, expected in saved['routine_reports'].items():
                        relative = Path(name)
                        if (relative.parent != Path('.DerivedData/Deliverables/Verification')
                                or not re.fullmatch(r'[0-9a-f]{64}', expected)):
                            continue
                        path = snapshot / 'files' / relative
                        ancestors = [path, *[p for p in path.parents if p.is_relative_to(common)]]
                        if (any(p.is_symlink() for p in ancestors) or not path.is_file()
                                or path.stat().st_mtime > now - 7 * 86400
                                or any(kept(p / '.retention-keep') for p in ancestors if p.is_dir())
                                or kept(path.with_name(path.name + '.retention-keep'))):
                            continue
                        if not routine_report(path) or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                            continue
                        opened = subprocess.run(['lsof', '-n', '-P', '--', str(path)], capture_output=True, text=True, timeout=30)
                        if opened.returncode != 1 or opened.stdout.strip() or opened.stderr.strip():
                            continue
                        journal = branch_dir / 'routine-expiry.jsonl'
                        if journal.is_symlink():
                            continue
                        with journal.open('a') as stream:
                            stream.write(json.dumps({'snapshot': snapshot.name, 'file': name, 'sha256': expected,
                                                     'scheduled_at': datetime.fromtimestamp(now, timezone.utc).isoformat()}) + '\n')
                            stream.flush()
                            os.fsync(stream.fileno())
                        if (any(p.is_symlink() for p in ancestors)
                                or any(kept(p / '.retention-keep') for p in ancestors if p.is_dir())
                                or kept(path.with_name(path.name + '.retention-keep'))
                                or not path.is_file() or path.stat().st_mtime > now - 7 * 86400
                                or hashlib.sha256(path.read_bytes()).hexdigest() != expected):
                            continue
                        path.unlink()
                        removed += 1
                except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
                    continue
    return removed


def expire_legacy_routine_evidence(source: Path, *, now: float | None = None, limit: int = 4) -> int:
    """Expire legacy static reports only when an integrated task report proves their provenance."""
    now = time.time() if now is None else now
    common = Path(git(source, 'rev-parse', '--path-format=absolute', '--git-common-dir')).resolve()
    root = common / 'trinket-evidence' / 'codex'
    if not root.is_dir() or root.is_symlink() or root.parent.is_symlink():
        return 0
    removed = 0
    ancestry = {}
    def kept(path: Path) -> bool:
        return path.exists() or path.is_symlink()
    with integration_lock(common):
        records = git(source, 'worktree', 'list', '--porcelain', '-z').split('\0\0')
        active = {line[len('branch refs/heads/'):] for record in records for line in record.split('\0')
                  if line.startswith('branch refs/heads/')}
        for branch_dir in sorted(root.iterdir()):
            if branch_dir.is_symlink() or not branch_dir.is_dir() or not re.fullmatch(r'[a-z0-9][a-z0-9_-]{0,63}', branch_dir.name):
                continue
            branch = 'codex/' + branch_dir.name
            if branch in active:
                continue
            for manifest in sorted(branch_dir.glob('*/evidence.json')):
                snapshot = manifest.parent
                task_report = snapshot / 'files/.DerivedData/Deliverables/task-report.json'
                if (snapshot.is_symlink() or manifest.is_symlink()
                        or any(path.is_symlink() for path in (task_report, *task_report.parents)
                               if path.is_relative_to(common))):
                    continue
                try:
                    saved = json.loads(manifest.read_text())
                    if 'routine_reports' in saved or saved['branch'] != branch or not isinstance(saved['files'], list):
                        continue
                    head = saved['preserved_at_commit']
                    if not re.fullmatch(r'[0-9a-f]{40}', head):
                        continue
                    task = json.loads(task_report.read_text())
                    if (task['branch'] != branch or task['static_verified_commit'] != head
                            or task['completion_state'] != 'locally integrated; hosted verification pending'
                            or not isinstance(task['verification_reports'], list)
                            or max(snapshot.stat().st_mtime, manifest.stat().st_mtime, task_report.stat().st_mtime) > now - 7 * 86400):
                        continue
                    if head not in ancestry:
                        result = subprocess.run(['git', '-C', str(source), 'merge-base', '--is-ancestor', head, 'main'],
                                                capture_output=True, timeout=5)
                        ancestry[head] = result.returncode == 0
                    if not ancestry[head]:
                        continue
                    for name in saved['files']:
                        relative = Path(name)
                        if relative.parent != Path('.DerivedData/Deliverables/Verification') or name not in task['verification_reports']:
                            continue
                        path = snapshot / 'files' / relative
                        ancestors = [path, *[p for p in path.parents if p.is_relative_to(common)]]
                        if (any(p.is_symlink() for p in ancestors) or not path.is_file()
                                or path.stat().st_mtime > now - 7 * 86400
                                or any(kept(p / '.retention-keep') for p in ancestors if p.is_dir())
                                or kept(path.with_name(path.name + '.retention-keep')) or not routine_report(path)):
                            continue
                        expected = hashlib.sha256(path.read_bytes()).hexdigest()
                        opened = subprocess.run(['lsof', '-n', '-P', '--', str(path)], capture_output=True, text=True, timeout=5)
                        if opened.returncode != 1 or opened.stdout.strip() or opened.stderr.strip():
                            continue
                        journal = branch_dir / 'routine-expiry.jsonl'
                        if journal.is_symlink():
                            continue
                        with journal.open('a') as stream:
                            stream.write(json.dumps({'snapshot': snapshot.name, 'file': name, 'sha256': expected,
                                                     'legacy': True, 'scheduled_at': datetime.fromtimestamp(now, timezone.utc).isoformat()}) + '\n')
                            stream.flush()
                            os.fsync(stream.fileno())
                        if (any(p.is_symlink() for p in ancestors)
                                or any(kept(p / '.retention-keep') for p in ancestors if p.is_dir())
                                or kept(path.with_name(path.name + '.retention-keep'))
                                or not path.is_file() or path.stat().st_mtime > now - 7 * 86400
                                or hashlib.sha256(path.read_bytes()).hexdigest() != expected):
                            continue
                        path.unlink()
                        removed += 1
                        if removed >= limit:
                            return removed
                except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
                    continue
    return removed


class ReviewRequired(RuntimeError):
    """The combined revision needs source review before a separate landing attempt."""


def integrate(source: Path, *, reviewed_main: str | None = None, keep_plan: bool = False) -> None:
    common, target = checkout_context(source)
    with integration_lock(common):
        if git(target, "branch", "--show-current") != "main":
            raise RuntimeError("Primary checkout must already be on main; no checkout was changed.")
        branch = git(source, "branch", "--show-current")
        if not branch.startswith("codex/"):
            raise RuntimeError("Integration requires a codex/ task branch.")
        clean(source)
        clean(target)
        base = git(target, "rev-parse", "HEAD")
        if reviewed_main is not None and not re.fullmatch(r'[a-f0-9]{40}', reviewed_main):
            raise RuntimeError('--reviewed-main requires the full reviewed commit ID, not a moving ref')
        if reviewed_main is not None and git(source, 'rev-parse', '--verify', '--end-of-options', reviewed_main + '^{commit}') != base:
            raise ReviewRequired('Main changed since the reviewed revision. Review current main and retry; no rebase or landing was performed.')
        previous_head = git(source, 'rev-parse', 'HEAD')
        new_main = git(source, 'merge-base', previous_head, base) != base
        preserve_ignored(source, base)
        # Preserve existing task commits, including a conflict for its owner to
        # resolve in isolation. Main remains untouched until verification passes.
        subprocess.run(["git", "-C", str(source), "rebase", "--rebase-merges", base], check=True)
        clean(source)
        head = git(source, "rev-parse", "HEAD")
        if head == base:
            print("Task already integrated; main unchanged.")
            preserve_default_evidence(source)
            print('Task checkout retained; use node Scripts/agent-worktree.mjs cleanup when finished.')
            return
        if new_main and reviewed_main is None:
            # A clean textual rebase is not semantic review or compiled evidence.
            # Retry the ordinary command after reviewing this combined revision;
            # another main advance will create another checkpoint.
            print(git(source, 'diff', '--stat', previous_head, head), flush=True)
            raise ReviewRequired(
                f'Incorporated main {base[:12]}; task is now {head[:12]}. Main was not advanced.\n'
                f'Review incoming changes: git diff {previous_head} {head}\n'
                'Refresh lightweight verification and visual evidence affected by these changes, '
                'then retry node Scripts/agent-worktree.mjs integrate. '
                'The retry runs the final static handoff once.'
            )
        paths = subprocess.check_output(
            ["git", "-C", str(source), "diff", "--name-only", "--no-renames", "-z", base, head]
        ).decode().rstrip("\0").split("\0")
        if paths == [""]:
            raise RuntimeError("No changed paths to verify; review empty task commits manually.")
        # Reuse installed executables without sharing writable build/generated
        # directories. Task-local tools take precedence; validators enforce pins.
        environment = dict(os.environ)
        from internal.cli import pinned_tool_path
        environment["PATH"] = pinned_tool_path(source, environment.get('PATH', ''))
        subprocess.run([str(source / "Scripts/handoff.sh"), "--route", "static", "--quiet", "--final",
                        *(["--keep-plan"] if keep_plan else []), "--paths", *paths],
                       cwd=source, env=environment, check=True)
        clean(source)
        if git(source, 'rev-parse', 'HEAD') != head:
            raise RuntimeError('Task commit changed during verification; review and retry')
        save_task_report(source, base, head, paths)
        saved = preserve_default_evidence(source)
        clean(source)
        clean(target)
        if (git(source, "rev-parse", "HEAD") != head
                or git(source, "branch", "--show-current") != branch
                or git(target, "rev-parse", "HEAD") != base
                or git(target, "branch", "--show-current") != "main"):
            raise RuntimeError("Checkout changed during verification; main was not advanced by this command. Retry after review.")
        preserve_ignored(target, head)
        subprocess.run(["git", "-C", str(target), "merge", "--ff-only", "--no-overwrite-ignore", head], check=True)
        report = save_task_report(source, base, head, paths, landed=True)
        if saved is not None:
            shutil.copy2(report, saved / 'files/.DerivedData/Deliverables/task-report.json', follow_symlinks=False)
        print(f"Integrated {branch} into local main at {head}. Nothing pushed; hosted checks remain pending.")
        print('Task checkout retained. Finish any remaining work, then run node Scripts/agent-worktree.mjs cleanup.')


if __name__ == "__main__":
    try:
        source = Path(__file__).resolve().parents[1]
        if sys.argv[1:] == ['--expire-routine-evidence']:
            count = expire_routine_evidence(source) + expire_legacy_routine_evidence(source)
            print(f'Expired {count} routine verification report(s).')
        elif sys.argv[1:2] == ['--evidence']:
            if sys.argv[2:]:
                preserve_evidence(source, sys.argv[2:])
            else:
                print(evidence_directory(source))
        elif sys.argv[1:] == ['--cleanup']:
            cleanup(source)
        else:
            import argparse
            parser = argparse.ArgumentParser(description='Land reviewed task work; retain the checkout until explicit cleanup.')
            parser.add_argument('--keep-worktree', action='store_true', help='compatibility flag; landing always keeps the checkout')
            parser.add_argument('--reviewed-main', help='full main commit ID already reviewed against this task')
            parser.add_argument('--keep-plan', action='store_true', help='retain intentionally unfinished plans; still validate their metadata and links')
            arguments = parser.parse_args()
            integrate(source, reviewed_main=arguments.reviewed_main, keep_plan=arguments.keep_plan)
    except ReviewRequired as error:
        print(str(error), file=sys.stderr)
        sys.exit(3)
    except (RuntimeError, ValueError, subprocess.CalledProcessError, OSError) as error:
        if sys.argv[1:2] == ['--evidence']:
            sys.exit(f'Evidence preservation stopped: {error}\nOriginal task files were retained.')
        sys.exit(f"Integration or cleanup stopped: {error}\nInspect main and the task/recovery checkout; completed integration is not rolled back. Resolve conflicts there, review, and retry; do not reset main. After a completed landing, retry cleanup with node Scripts/agent-worktree.mjs cleanup.")
