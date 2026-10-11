#!/usr/bin/env python3
"""Serialize verified, local-only task landings into the primary main checkout."""

from __future__ import annotations

import fcntl
import os
from pathlib import Path
import subprocess
import sys


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


def integrate(source: Path) -> None:
    common = Path(git(source, "rev-parse", "--path-format=absolute", "--git-common-dir"))
    # Git lists the primary checkout first; bare repositories are not landing targets.
    records = git(source, "worktree", "list", "--porcelain", "-z").split("\0\0")
    primary = records[0].split("\0")
    if "bare" in primary or not primary[0].startswith("worktree "):
        raise RuntimeError("A non-bare primary checkout on main is required.")
    target = Path(primary[0][len("worktree "):]).resolve()
    if source == target:
        raise RuntimeError("Run integration from the isolated task worktree, not the primary checkout.")
    # An OS-held lock releases on exit/crash. Never unlink this file: all callers
    # must lock the same inode, including callers in different linked worktrees.
    with (common / "trinket-integration.lock").open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("Integration busy. Retry later without messaging other chats.") from None
        if git(target, "branch", "--show-current") != "main":
            raise RuntimeError("Primary checkout must already be on main; no checkout was changed.")
        branch = git(source, "branch", "--show-current")
        if not branch.startswith("codex/"):
            raise RuntimeError("Integration requires a codex/ task branch.")
        clean(source)
        clean(target)
        base = git(target, "rev-parse", "HEAD")
        preserve_ignored(source, base)
        # Preserve existing task commits, including a conflict for its owner to
        # resolve in isolation. Main remains untouched until verification passes.
        subprocess.run(["git", "-C", str(source), "rebase", "--rebase-merges", base], check=True)
        clean(source)
        head = git(source, "rev-parse", "HEAD")
        if head == base:
            print("Task already integrated; main unchanged.")
            return
        paths = subprocess.check_output(
            ["git", "-C", str(source), "diff", "--name-only", "--no-renames", "-z", base, head]
        ).decode().rstrip("\0").split("\0")
        if paths == [""]:
            raise RuntimeError("No changed paths to verify; review empty task commits manually.")
        # Reuse installed executables without sharing writable build/generated
        # directories. Task-local tools take precedence; validators enforce pins.
        environment = dict(os.environ)
        environment["PATH"] = os.pathsep.join((str(source / ".tools"), str(target / ".tools"), environment["PATH"]))
        subprocess.run([str(source / "Scripts/handoff.sh"), "--isolate", "--quiet", "--paths", *paths],
                       cwd=source, env=environment, check=True)
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


if __name__ == "__main__":
    if len(sys.argv) != 1:
        sys.exit("Usage: python3 Scripts/agent-integrate.py (from the task worktree)")
    try:
        integrate(Path(__file__).resolve().parents[1])
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        sys.exit(f"Integration stopped: {error}\nTask worktree retained. Resolve conflicts there, review, and retry; do not reset main.")
