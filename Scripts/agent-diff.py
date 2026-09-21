#!/usr/bin/env python3
"""Read authored diffs while explicitly disclosing generated and untracked changes."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

from internal.cli import ROOT
from internal.generated_summary import generated_summary


def patch_units(patch: str) -> list[str]:
    """Repeat file headers on each complete hunk so pages are independently readable."""
    units = []
    for file in re.split(r"(?=^diff --git )", patch, flags=re.MULTILINE):
        if not file:
            continue
        hunks = re.split(r"(?=^@@ )", file, flags=re.MULTILINE)
        units.extend([hunks[0] + hunk for hunk in hunks[1:]] or hunks)
    return units


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    state = parser.add_mutually_exclusive_group()
    state.add_argument("--staged", action="store_true", help="compare index with HEAD")
    state.add_argument("--unstaged", action="store_true", help="compare working files with index (default)")
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--paths", nargs="+", help="individual repository-relative files, including deletions")
    scope.add_argument("--working-tree", action="store_true", help="intentionally inspect every path")
    parser.add_argument("--generated", action="store_true", help="also expand generated patches")
    parser.add_argument("--summary", action="store_true", help="add record/field hints for supported generated catalogs")
    parser.add_argument("--stat", action="store_true", help="show authored statistics without patches")
    parser.add_argument("--max-chars", type=int, default=12000, help="page content budget (default: 12000 characters)")
    parser.add_argument("--start", type=int, default=0, help="resume at a reported unit offset")
    parser.add_argument("--expect", help="reject continuation if the diff changed")
    parser.add_argument("--full", action="store_true", help="explicitly print all units without a budget")
    args = parser.parse_args(argv)
    if args.max_chars < 1 or args.start < 0:
        parser.error("--max-chars must be positive and --start nonnegative")
    paths = []
    for name in args.paths or []:
        path = Path(name)
        if path.is_absolute() or ".." in path.parts or path.as_posix() == "." or (root / path).is_dir():
            parser.error("--paths requires individual repository-relative files")
        paths.append(path.as_posix())
    generated = [line.split("|", 1)[1].rstrip("/")
                 for line in (root / "Scripts/config/generated-paths.tsv").read_text().splitlines()
                 if line and not line.startswith("#")]

    def is_generated(name: str) -> bool:
        return any(name == entry or name.startswith(entry + "/") for entry in generated)

    def git(*command: str) -> bytes:
        return subprocess.check_output(["git", "--literal-pathspecs", *command], cwd=root)

    # Disabling rename detection exposes both endpoints, including moves between
    # authored and generated ownership, without hiding either side of the change.
    diff = ["diff", "--no-ext-diff", "--no-textconv", "--no-renames", "--no-color"]
    if args.staged:
        diff.append("--cached")
    records = git(*diff, "--numstat", "-z", "--", *paths).decode().split("\0")
    authored, outputs = [], []
    for record in filter(None, records):
        added, removed, name = record.split("\t", 2)
        (outputs if is_generated(name) else authored).append((name, added, removed))
    units, summary_versions = [], []
    for label, rows in (("Authored", authored), ("Generated (expand with --generated)", outputs)):
        if rows:
            for name, added, removed in rows:
                units.append(f"{label}: +{added} -{removed} {json.dumps(name, ensure_ascii=False)}\n")
    if args.summary:
        def version(spec):
            revision, name = spec.split(':', 1)
            if not revision:
                exists = git('ls-files', '--stage', '-z', '--', name)
            else:
                head = subprocess.run(['git', 'rev-parse', '--verify', 'HEAD'], cwd=root, capture_output=True)
                if head.returncode:
                    # A staged addition in an unborn repository has no prior content.
                    return b''
                exists = git('ls-tree', '-z', revision, '--', name)
            if not exists:
                return b''
            return git('show', spec)
        for name, _, _ in outputs:
            before = version(('HEAD:' if args.staged else ':') + name)
            after = version(':' + name) if args.staged else (root / name).read_bytes() if (root / name).exists() else b''
            summary_versions.append(hashlib.sha256(before + b'\0' + after).hexdigest())
            units.extend(generated_summary(name, before, after, staged=args.staged))
    expanded = authored + (outputs if args.generated else [])
    if expanded and not args.stat:
        units.extend(patch_units(git(*diff, "--", *(name for name, _, _ in expanded)).decode()))
    if not args.staged:
        untracked = list(filter(None, git("ls-files", "--others", "--exclude-standard", "-z", "--", *paths).decode().split("\0")))
        if untracked:
            units.append(f"Untracked: {len(untracked)} files (not included in Git patches; read explicitly):\n")
            for name in untracked:
                units.append(f"  {'generated' if is_generated(name) else 'authored'} {json.dumps(name, ensure_ascii=False)}\n")
    digest = hashlib.sha256("".join(units + summary_versions).encode()).hexdigest()
    if args.expect and args.expect != digest:
        print("Diff changed since the previous page; restart review at --start 0.", file=sys.stderr)
        return 2
    if args.start > len(units):
        parser.error("--start is beyond the last unit")
    print(f"Diff: {'staged' if args.staged else 'unstaged'}; {len(authored)} authored, {len(outputs)} generated files")
    stop, used = args.start, 0
    while stop < len(units) and (args.full or used + len(units[stop]) <= args.max_chars):
        print(units[stop], end="")
        used += len(units[stop])
        stop += 1
    print(f"Review units {args.start}:{stop} of {len(units)}; omitted {len(units) - stop} units after this page.")
    if stop < len(units):
        budget = max(args.max_chars, len(units[stop])) if stop == args.start else args.max_chars
        if stop == args.start:
            print(f"Next complete hunk/record needs {budget} characters; it was not truncated.")
        command = ["python3", "Scripts/agent-diff.py", "--start", str(stop), "--expect", digest,
                   "--max-chars", str(budget)]
        command += [flag for flag, enabled in (("--staged", args.staged), ("--generated", args.generated), ("--summary", args.summary), ("--stat", args.stat)) if enabled]
        command += ["--working-tree"] if args.working_tree else ["--paths", *paths]
        print("Continue: " + shlex.join(command))
        print("Review every relevant page before editing overlapping changes; --full explicitly expands all output.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Diff failed: {error}", file=sys.stderr)
        raise SystemExit(2)
