#!/usr/bin/env python3
"""Serialize verified, local-only task landings into the primary main checkout."""

from __future__ import annotations

import fcntl
from contextlib import contextmanager
import os
from pathlib import Path
import subprocess
import sys
import json
import tempfile
import shutil


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


def preserve_evidence(source: Path, names: list[str]) -> Path:
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
    saved = Path(tempfile.mkdtemp(prefix=head[:12] + '-', dir=destination))
    for path in sorted(set(paths)):
        target = saved / 'files' / path.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target, follow_symlinks=False)
    (saved / 'evidence.json').write_text(json.dumps({
        'preserved_at_commit': head, 'branch': git(source, 'branch', '--show-current'),
        'files': [str(path.relative_to(source)) for path in sorted(set(paths))],
    }, indent=2) + '\n')
    print(f'Preserved task evidence: {saved}')
    return saved


def preserve_default_evidence(source: Path) -> None:
    deliverables = source / '.DerivedData/Deliverables'
    if deliverables.exists() or deliverables.is_symlink():
        preserve_evidence(source, ['.DerivedData/Deliverables'])


def save_task_report(source: Path, base: str, head: str, paths: list[str]) -> None:
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
        'limitations': 'Static handoff only; compiled, hosted and visual evidence is recorded separately.',
    })


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
        remove_integrated_worktree(source, target, branch, head, main_head=main_head)


class ReviewRequired(RuntimeError):
    """The combined revision needs source review before a separate landing attempt."""


def integrate(source: Path, *, keep_worktree: bool = False) -> None:
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
            if not keep_worktree:
                remove_integrated_worktree(source, target, branch, head)
            return
        if new_main:
            # A clean textual rebase is not semantic review or compiled evidence.
            # Retry the ordinary command after reviewing this combined revision;
            # another main advance will create another checkpoint.
            print(git(source, 'diff', '--stat', previous_head, head), flush=True)
            raise ReviewRequired(
                f'Incorporated main {base[:12]}; task is now {head[:12]}. Main was not advanced.\n'
                f'Review incoming changes: git diff {previous_head} {head}\n'
                'Refresh focused verification and visual evidence affected by these changes, '
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
        subprocess.run([str(source / "Scripts/handoff.sh"), "--isolate", "--quiet", "--paths", *paths],
                       cwd=source, env=environment, check=True)
        clean(source)
        if git(source, 'rev-parse', 'HEAD') != head:
            raise RuntimeError('Task commit changed during verification; review and retry')
        save_task_report(source, base, head, paths)
        preserve_default_evidence(source)
        clean(source)
        clean(target)
        if (git(source, "rev-parse", "HEAD") != head
                or git(source, "branch", "--show-current") != branch
                or git(target, "rev-parse", "HEAD") != base
                or git(target, "branch", "--show-current") != "main"):
            raise RuntimeError("Checkout changed during verification; main was not advanced by this command. Retry after review.")
        preserve_ignored(target, head)
        subprocess.run(["git", "-C", str(target), "merge", "--ff-only", "--no-overwrite-ignore", head], check=True)
        print(f"Integrated {branch} into local main at {head}. Nothing pushed; hosted checks remain pending.")
        if not keep_worktree:
            remove_integrated_worktree(source, target, branch, head)


if __name__ == "__main__":
    try:
        source = Path(__file__).resolve().parents[1]
        if sys.argv[1:2] == ['--evidence']:
            if sys.argv[2:]:
                preserve_evidence(source, sys.argv[2:])
            else:
                print(evidence_directory(source))
        elif sys.argv[1:] in ([], ['--keep-worktree']):
            integrate(source, keep_worktree='--keep-worktree' in sys.argv)
        elif sys.argv[1:] == ['--cleanup']:
            cleanup(source)
        else:
            sys.exit('Usage: agent-integrate.py [--keep-worktree | --cleanup | --evidence [path...]]')
    except ReviewRequired as error:
        print(str(error), file=sys.stderr)
        sys.exit(3)
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        if sys.argv[1:2] == ['--evidence']:
            sys.exit(f'Evidence preservation stopped: {error}\nOriginal task files were retained.')
        sys.exit(f"Integration or cleanup stopped: {error}\nInspect main and the task/recovery checkout; completed integration is not rolled back. Resolve conflicts there, review, and retry; do not reset main. After a completed landing, retry cleanup with node Scripts/agent-worktree.mjs cleanup.")
