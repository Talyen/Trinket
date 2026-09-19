#!/usr/bin/env python3
"""Read authored diffs while explicitly disclosing generated and untracked changes."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from internal.cli import ROOT


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    state = parser.add_mutually_exclusive_group()
    state.add_argument("--staged", action="store_true", help="compare index with HEAD")
    state.add_argument("--unstaged", action="store_true", help="compare working files with index (default)")
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--paths", nargs="+", help="individual repository-relative files, including deletions")
    scope.add_argument("--working-tree", action="store_true", help="intentionally inspect every path")
    parser.add_argument("--generated", action="store_true", help="also expand generated patches")
    parser.add_argument("--stat", action="store_true", help="show authored statistics without patches")
    args = parser.parse_args(argv)
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
    print(f"Diff: {'staged' if args.staged else 'unstaged'}; {len(authored)} authored, {len(outputs)} generated files")
    for label, rows in (("Authored", authored), ("Generated (expand with --generated)", outputs)):
        if rows:
            print(label + ":")
            for name, added, removed in rows:
                print(f"  +{added} -{removed} {json.dumps(name, ensure_ascii=False)}")
    expanded = authored + (outputs if args.generated else [])
    if expanded and not args.stat:
        print(git(*diff, "--", *(name for name, _, _ in expanded)).decode(), end="")
    if not args.staged:
        untracked = list(filter(None, git("ls-files", "--others", "--exclude-standard", "-z", "--", *paths).decode().split("\0")))
        if untracked:
            print(f"Untracked: {len(untracked)} files (not included in Git patches; read explicitly):")
            for name in untracked:
                print(f"  {'generated' if is_generated(name) else 'authored'} {json.dumps(name, ensure_ascii=False)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Diff failed: {error}", file=sys.stderr)
        raise SystemExit(2)
