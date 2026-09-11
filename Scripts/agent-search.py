#!/usr/bin/env python3
"""Bounded, authored-first discovery over Git's file inventory; rg owns matching."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXT_SUFFIXES = {
    ".swift", ".metal", ".sh", ".py", ".mjs", ".js", ".ts", ".tsx",
    ".env", ".json", ".yml", ".yaml", ".tsv", ".toml", ".pbxproj",
    ".xctestplan", ".xcprivacy", ".entitlements", ".plist", ".md", ".txt",
}


def inventory(root: Path, mode: str, scopes: list[str]) -> list[str]:
    generated = [
        line.split("|", 1)[1].rstrip("/")
        for line in (root / "Scripts/config/generated-paths.tsv").read_text().splitlines()
        if line and not line.startswith("#")
    ]
    files = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=root,
    ).decode().split("\0")
    selected = []
    for name in sorted(set(files) - {""}):
        path = root / name
        if path.is_symlink() or not path.is_file():
            continue
        if scopes and not any(name == scope or name.startswith(scope + "/") for scope in scopes):
            continue
        is_generated = any(name == entry or name.startswith(entry + "/") for entry in generated)
        is_generated |= "/Generated/" in name or ".generated." in name
        is_docs = path.suffix == ".md"
        is_test = any(part == "Tests" or part.endswith("TestSupport") or part == "TrinketUITests"
                      for part in path.relative_to(root).parts)
        category = "generated" if is_generated else "docs" if is_docs else "tests" if is_test else "source"
        if category == mode and (path.suffix in TEXT_SUFFIXES or name.startswith((".githooks/", "Scripts/bin/"))):
            selected.append(name)
    return selected


def positive(value: str) -> int:
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pattern", help="rg regular expression; use -- before a pattern starting with -")
    parser.add_argument("--mode", choices=("source", "tests", "docs", "generated"), default="source")
    parser.add_argument("--scope", action="append", default=[], help="repository-relative file or directory; repeatable")
    parser.add_argument("--excerpts", action="store_true", help="show matching lines and context instead of file counts")
    parser.add_argument("--limit", type=positive, default=20, help="maximum files or excerpt lines displayed (default: 20)")
    parser.add_argument("--context", type=int, choices=range(0, 6), default=2, help="excerpt context lines (0–5; default: 2)")
    parser.add_argument("-i", "--ignore-case", action="store_true")
    parser.add_argument("-F", "--fixed-strings", action="store_true")
    args = parser.parse_args(argv)
    scopes = []
    for scope in args.scope:
        candidate = Path(scope)
        if candidate.is_absolute() or ".." in candidate.parts:
            parser.error("--scope must stay within the repository")
        normalized = candidate.as_posix().rstrip("/")
        if normalized != ".":
            scopes.append(normalized)
    files = inventory(root, args.mode, scopes)
    print(f"Search: {args.mode}; {len(files)} text files; scope: {', '.join(scopes) or 'repository'}")
    if not files:
        print("No files in this search surface. Choose another --mode or --scope.")
        return 1
    command = ["rg", "--json", "--sort", "path"]
    if args.ignore_case:
        command.append("--ignore-case")
    if args.fixed_strings:
        command.append("--fixed-strings")
    if args.excerpts:
        command.extend(["--context", str(args.context)])
    result = subprocess.run([*command, "--", args.pattern, *files], cwd=root, capture_output=True, text=True)
    if result.returncode not in (0, 1):
        print(result.stderr, file=sys.stderr, end="")
        return result.returncode
    counts: Counter[str] = Counter()
    excerpts = []
    for raw in result.stdout.splitlines():
        event = json.loads(raw)
        if event["type"] not in ("match", "context"):
            continue
        data = event["data"]
        name = data["path"]["text"]
        if event["type"] == "match":
            counts[name] += 1
        if args.excerpts:
            line = data["lines"].get("text")
            if line is None:
                line = "[non-UTF-8 line; inspect the file directly]"
            excerpts.append(f"{name}:{data['line_number']}: {line.rstrip()}")
    rows = excerpts if args.excerpts else [f"{name}: {count} matching lines" for name, count in counts.items()]
    shortened = 0
    for row in rows[:args.limit]:
        if args.excerpts and len(row) > 300:
            row = row[:299] + "…"
            shortened += 1
        print(row)
    omitted = max(0, len(rows) - args.limit)
    unit = "excerpt lines" if args.excerpts else "files"
    print(f"Matched {sum(counts.values())} lines in {len(counts)} files; omitted {omitted} {unit}; shortened {shortened} lines.")
    if omitted or shortened:
        print("Narrow --scope, raise --limit, or read the selected file with rg/sed for complete text.")
    return result.returncode


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Search failed: {error}", file=sys.stderr)
        sys.exit(2)
