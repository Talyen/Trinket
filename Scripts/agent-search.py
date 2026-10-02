#!/usr/bin/env python3
"""Bounded, authored-first discovery over Git's file inventory; rg owns matching."""

from __future__ import annotations

import argparse
import fnmatch
import difflib
import hashlib
import shlex
import json
import re
import subprocess
import sys
from collections import Counter
from itertools import zip_longest
from pathlib import Path

from internal.cli import ROOT
from internal.agent_arguments import AgentArgumentParser
from internal.agent_tasks import find_tasks, related_tests
TEXT_SUFFIXES = {
    ".swift", ".metal", ".sh", ".py", ".mjs", ".js", ".ts", ".tsx",
    ".env", ".json", ".yml", ".yaml", ".tsv", ".toml", ".pbxproj",
    ".xctestplan", ".xcprivacy", ".entitlements", ".plist", ".md", ".mdc", ".txt",
}
ASSET_SUFFIXES = {".png", ".jpg", ".jpeg", ".heic", ".webp", ".gif", ".svg", ".pdf",
                  ".wav", ".mp3", ".m4a", ".aac", ".aiff", ".ogg", ".caf", ".mp4", ".mov"}


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
        if name.startswith(".agents/friction-archive/") and not any(
            scope == ".agents/friction-archive" or scope.startswith(".agents/friction-archive/")
            for scope in scopes
        ):
            continue
        if mode == "overview" or (mode == "assets" and (
            path.suffix.lower() in ASSET_SUFFIXES or name.startswith("Raw Assets/")
            or ".xcassets/" in name or name.startswith("Trinket/Media/")
        )):
            selected.append(name)
            continue
        is_generated = any(name == entry or name.startswith(entry + "/") for entry in generated)
        is_generated |= "/Generated/" in name or ".generated." in name
        is_docs = path.suffix in {".md", ".mdc"}
        is_test = any(part == "Tests" or part.endswith("TestSupport") or part == "TrinketUITests"
                      for part in path.relative_to(root).parts)
        category = "generated" if is_generated else "docs" if is_docs else "tests" if is_test else "source"
        if category == mode and (path.suffix in TEXT_SUFFIXES or name.startswith((".githooks/", "Scripts/bin/"))):
            selected.append(name)
    return selected


def documentation_order(name: str) -> tuple[int, str]:
    if name.startswith(("Docs/Plans/", ".agents/evals/", ".agents/friction-archive/")) or name in {
        ".agents/FRICTION_LOG.md", "Docs/Audits/Proposals.md",
    }:
        return (2, name)
    if name.startswith((".agents/skills/", ".agents/knowledge/", "Docs/Audits/")):
        return (1, name)
    return (0, name)


def positive(value: str) -> int:
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def scope_spelling(root: Path, scope: Path) -> str | None:
    """Resolve exact spelling for navigation only; never silently widen a search."""
    current = root
    parts = []
    for part in scope.parts:
        if not current.is_dir():
            return None
        names = sorted(child.name for child in current.iterdir())
        matches = [name for name in names if name.casefold() == part.casefold()]
        if not matches:
            matches = difflib.get_close_matches(part, names, n=1, cutoff=0.75)
        if len(matches) != 1:
            return None
        parts.append(matches[0])
        current /= matches[0]
    return '/'.join(parts)


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = AgentArgumentParser("agent-search.py", description=__doc__)
    parser.add_argument("pattern", nargs="?", help="rg regular expression; use -- before a pattern starting with -")
    parser.add_argument("--mode", choices=("source", "tests", "docs", "generated", "assets"), default="source")
    parser.add_argument("--overview", action="store_true", help="page owner counts and entry points without listing assets")
    parser.add_argument("--scope", action="append", default=[], help="repository-relative file or directory; repeatable")
    parser.add_argument("--excerpts", action="store_true", help="show matching lines and context instead of file counts")
    parser.add_argument("--files", action="store_true", help="match relative filenames instead of file contents")
    parser.add_argument("--glob", action="store_true", help="with --files, use a case-sensitive shell pattern instead of regex; * crosses directories")
    parser.add_argument("--related", action="store_true", help="bounded declaration, reference, and test-file hints for one identifier within the scopes")
    parser.add_argument("--callers", action="store_true", help="lexical invocation locations and enclosing declarations for one Swift/Python identifier")
    parser.add_argument("--task", action="store_true", help="look up a player-facing concern in the small authored task index")
    parser.add_argument("--limit", type=positive, default=20, help="maximum files or excerpt lines displayed (default: 20)")
    parser.add_argument("--context", type=int, choices=range(0, 6), default=2, help="excerpt context lines (0–5; default: 2)")
    parser.add_argument("-i", "--ignore-case", action="store_true")
    parser.add_argument("-F", "--fixed-strings", action="store_true")
    parser.add_argument("--offset", type=int, default=0, help="result offset from a continuation command")
    parser.add_argument("--expect", help="reject continuation if search results changed")
    args = parser.parse_args(argv)
    if args.overview:
        if args.pattern is not None or args.files or args.excerpts or args.glob or args.related or args.callers or args.task or args.mode != "source":
            parser.error("--overview accepts scopes and pagination, not a pattern, --mode, --files, or --excerpts")
    elif args.pattern is None:
        parser.error("a pattern is required unless --overview is selected")
    if args.mode == "assets" and not args.files:
        parser.error("--mode assets requires --files; asset contents are not searched")
    if args.offset < 0:
        parser.error("--offset must be nonnegative")
    if args.files and args.excerpts:
        parser.error("--files and --excerpts are mutually exclusive")
    if args.glob and (not args.files or args.fixed_strings):
        parser.error("--glob requires --files and cannot combine with -F")
    if args.related and (args.mode != "source" or args.files or args.excerpts or args.glob
                         or not re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", args.pattern or "")):
        parser.error("--related requires one plain identifier in source mode, without --files or --excerpts")
    if args.related and args.fixed_strings:
        parser.error("--related uses identifier boundaries and cannot combine with -F")
    if args.callers and (args.mode not in {'source', 'tests'} or args.related or args.files or args.excerpts
                         or args.glob or args.fixed_strings or args.ignore_case
                         or not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', args.pattern or '')):
        parser.error('--callers requires one exact identifier in source or tests mode without other search modes')
    if args.task and (args.mode != "source" or args.related or args.callers or args.files or args.excerpts or args.glob or args.fixed_strings or args.ignore_case):
        parser.error("--task accepts a concern name, scopes and pagination; it cannot combine with other search modes")
    scopes = []
    for scope in args.scope:
        candidate = Path(scope)
        if candidate.is_absolute() or ".." in candidate.parts:
            parser.error("--scope must stay within the repository")
        normalized = candidate.as_posix().rstrip("/")
        spelling = scope_spelling(root, candidate)
        if normalized != '.' and (not (root / candidate).exists() or (spelling and spelling != normalized)):
            print(f"Invalid scope: {scope}; use an exact repository file or directory.", file=sys.stderr)
            if spelling:
                retry = list(sys.argv[1:] if argv is None else argv)
                for index, argument in enumerate(retry[:-1]):
                    if argument == '--scope' and retry[index + 1] == scope:
                        retry[index + 1] = spelling
                retry = [('--scope=' + spelling) if arg == '--scope=' + scope else arg for arg in retry]
                # A corrected surface must start a fresh search.
                for flag in ('--expect', '--offset'):
                    while flag in retry:
                        index = retry.index(flag)
                        del retry[index:index + 2]
                retry = [arg for arg in retry if not arg.startswith(('--expect=', '--offset='))]
                print('Try: ' + shlex.join(['python3', 'Scripts/agent-search.py', *retry]), file=sys.stderr)
            else:
                print('Try: python3 Scripts/agent-search.py --overview', file=sys.stderr)
            return 2
        if normalized != ".":
            scopes.append(normalized)
    files = [] if args.task else inventory(root, "overview" if args.overview else args.mode, scopes)
    test_files = set(inventory(root, "tests", scopes)) if args.related else set()
    if args.related:
        files = sorted(set(files) | test_files)
    surface = "task" if args.task else "overview" if args.overview else "related" if args.related else args.mode
    unit = "files" if args.overview or args.mode == "assets" else "text files"
    print(f"Search: task index; scope: {', '.join(scopes) or 'repository'}" if args.task else
          f"Search: {surface}; {len(files)} {unit}; scope: {', '.join(scopes) or 'repository'}")
    if args.mode == "docs":
        print("Order: current documentation, procedures/knowledge, then task records (alphabetical within each).")
        print("Friction archives require --scope .agents/friction-archive or a file within it.")
    if not files and not args.task:
        if args.expect or args.offset:
            print("Search results changed or offset is beyond the empty surface; restart at --offset 0.", file=sys.stderr)
            return 2
        print("No files in this search surface. Choose another --mode or --scope.")
        return 1
    command = ["rg", "--json", "--sort", "path"]
    if args.ignore_case:
        command.append("--ignore-case")
    if args.fixed_strings:
        command.append("--fixed-strings")
    declarations: dict[str, int] = {}

    def order(name: str):
        if args.mode == "docs":
            return documentation_order(name)
        identifier = re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", args.pattern)
        stem = Path(name).stem
        exact = stem.casefold() == args.pattern.casefold() if args.ignore_case else stem == args.pattern
        words = re.findall(r"[A-Z]+(?=[A-Z][a-z]|$)|[A-Z]?[a-z]+|[0-9]+", stem)
        relevant = stem.casefold().startswith(args.pattern.casefold()) or any(
            word.casefold().startswith(args.pattern.casefold()) for word in words)
        return (0 if identifier and exact else 1 if identifier and relevant else
                2 if name in declarations else 3, name)

    def render(rows: list[str], summary: str, unit: str) -> int:
        identity = [args.pattern, surface, scopes, args.files, args.excerpts, args.ignore_case,
                    args.fixed_strings, args.glob, args.related, args.callers, args.task, args.context, rows]
        digest = hashlib.sha256(json.dumps(identity).encode()).hexdigest()
        if args.expect and args.expect != digest:
            print("Search results changed; restart at --offset 0.", file=sys.stderr)
            return 2
        if args.offset > len(rows):
            print("--offset is beyond the last result.", file=sys.stderr)
            return 2
        stop = min(len(rows), args.offset + args.limit)
        shortened = 0
        for row in rows[args.offset:stop]:
            if args.excerpts and len(row) > 300:
                row = row[:299] + "…"
                shortened += 1
            print(row)
        print(f"{summary}; omitted {len(rows) - stop} {unit}; shortened {shortened} lines.")
        print(f"Results {args.offset}:{stop} of {len(rows)}.")
        if stop < len(rows):
            continuation = ["python3", "Scripts/agent-search.py", "--mode", args.mode,
                            "--offset", str(stop), "--limit", str(args.limit), "--expect", digest,
                            "--context", str(args.context)]
            for scope in scopes:
                continuation += ["--scope", scope]
            for flag, enabled in [("--files", args.files), ("--excerpts", args.excerpts),
                                  ("--glob", args.glob), ("--related", args.related), ("--task", args.task),
                                  ("--callers", args.callers),
                                  ("-i", args.ignore_case), ("-F", args.fixed_strings)]:
                if enabled:
                    continuation.append(flag)
            if args.overview:
                continuation += ["--overview"]
            else:
                continuation += ["--", args.pattern]
            print("Continue: " + shlex.join(continuation))
        if shortened:
            print("Read the selected source range for complete shortened lines.")
        return 0 if rows else 1

    if args.task:
        rows = find_tasks(root, args.pattern, scopes)
        print("Concern pointers can cross owners; route the source paths. Test pointers are not coverage proof.")
        if not rows:
            print("No indexed concern matched. Try: python3 Scripts/agent-search.py --overview")
        return render(rows, f"Matched {len(rows)} indexed concerns", "concerns")

    if args.overview:
        owners: dict[str, list[str]] = {}
        for name in files:
            parts = Path(name).parts
            depth = 2 if parts[0] in {"Packages", "Docs", "Trinket", "Raw Assets", ".agents"} else 1
            owner = "/".join(parts[:depth]) if len(parts) > depth else "." if len(parts) == 1 else parts[0]
            owners.setdefault(owner, []).append(name)
        rows = []
        def owner_order(item):
            owner = item[0]
            if owner == ".":
                rank = 0
            elif owner.startswith("Packages/"):
                rank = 1
            elif owner.startswith(("Raw Assets", "Trinket/Assets.xcassets", "Trinket/Media")):
                rank = 7
            elif owner.startswith("Trinket/"):
                rank = 2
            elif owner == "Scripts":
                rank = 3
            elif owner.endswith("Manifest"):
                rank = 4
            elif owner.startswith("Docs/"):
                rank = 5
            else:
                rank = 6
            return rank, owner
        for owner, names in sorted(owners.items(), key=owner_order):
            entries = sorted(name for name in names if Path(name).name in {"README.md", "AGENTS.md", "Package.swift", "project.yml"})
            entries.sort(key=lambda name: (len(Path(name).parts), name))
            entry_text = ", ".join(entries[:2]) or "scope filename searches here"
            row = f"{owner}: {len(names)} files; entry: {entry_text}"
            rows.append(json.dumps(row) if any(c in row for c in "\n\r\t") else row)
        return render(rows, f"Grouped {len(files)} files into {len(rows)} owners", "owners")

    if args.files:
        if args.glob:
            pattern = args.pattern.casefold() if args.ignore_case else args.pattern
            def matches(name: str) -> bool:
                candidate = name.casefold() if args.ignore_case else name
                return fnmatch.fnmatchcase(candidate, pattern) or (
                    "/" not in pattern and fnmatch.fnmatchcase(Path(candidate).name, pattern))
            names = sorted((name for name in files if matches(name)), key=order)
            rows = [json.dumps(name) if any(c in name for c in "\n\r\t") else name for name in names]
            return render(rows, f"Matched {len(names)} files (glob)", "files")
        result = subprocess.run([*command, "--null-data", "--", args.pattern], input="\0".join(files) + "\0",
                                cwd=root, capture_output=True, text=True)
        if result.returncode not in (0, 1):
            print(result.stderr, file=sys.stderr, end="")
            if not args.fixed_strings and "regex parse error" in result.stderr and any(c in args.pattern for c in "*?["):
                retry = ["python3", "Scripts/agent-search.py", "--mode", args.mode, "--files", "--glob"]
                for scope in scopes:
                    retry += ["--scope", scope]
                if args.ignore_case:
                    retry.append("-i")
                retry += ["--limit", str(args.limit), "--", args.pattern]
                print("If this is a shell filename pattern, retry: " + shlex.join(retry), file=sys.stderr)
            return result.returncode
        names = sorted((event["data"]["lines"]["text"].removesuffix("\0")
                        for raw in result.stdout.splitlines()
                        if (event := json.loads(raw))["type"] == "match"), key=order)
        rows = [json.dumps(name) if any(c in name for c in "\n\r\t") else name for name in names]
        return render(rows, f"Matched {len(names)} files", "files")
    if args.excerpts:
        command.extend(["--context", str(args.context)])
    pattern = rf"\b{re.escape(args.pattern)}\b" if args.related or args.callers else args.pattern
    result = subprocess.run([*command, "--", pattern, *files], cwd=root, capture_output=True, text=True)
    if result.returncode not in (0, 1):
        print(result.stderr, file=sys.stderr, end="")
        return result.returncode
    counts: Counter[str] = Counter()
    identifier = re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", args.pattern)
    declaration = re.compile(
        rf"^\s*(?:(?:public|package|internal|private|fileprivate|final|static|class|open|indirect|nonisolated|override|async)\s+)*"
        rf"(?:struct|class|enum|actor|protocol|typealias|func|def|function|let|var|const)\s+`?{re.escape(args.pattern)}`?\b",
        re.IGNORECASE if args.ignore_case else 0,
    ) if identifier and args.mode != "docs" else None
    excerpts = []
    references: dict[str, int] = {}
    tests: dict[str, int] = {}
    for raw in result.stdout.splitlines():
        event = json.loads(raw)
        if event["type"] not in ("match", "context"):
            continue
        data = event["data"]
        name = data["path"]["text"]
        if event["type"] == "match":
            counts[name] += 1
            if args.related and name in test_files:
                tests.setdefault(name, data["line_number"])
            elif declaration and declaration.search(data["lines"].get("text", "")):
                declarations.setdefault(name, data["line_number"])
            else:
                references.setdefault(name, data["line_number"])
        if args.excerpts:
            line = data["lines"].get("text")
            if line is None:
                line = "[non-UTF-8 line; inspect the file directly]"
            excerpts.append((name, data["line_number"], line.rstrip()))
    if args.callers:
        from internal.agent_callers import caller_rows
        print('Lexical invocation hints: excludes comments/literals; no type resolution, indirect calls, or Swift interpolation/trailing-closure/generic-only calls.')
        rows = caller_rows(root, sorted(counts, key=order), args.pattern)
        return render(rows, f'Matched {len(rows)} invocation locations', 'invocations')
    if args.related:
        print("Textual hints only: references can be comments/strings; test mentions do not prove coverage.")
        curated = related_tests(root, args.pattern, set(files) - test_files, test_files, args.ignore_case) - set(tests)
        for name in curated:
            tests[name] = 1
        # A declaration file may also contain references. Keep one row per file
        # while preserving both roles and interleaving tests with production code.
        combined = set(declarations) & set(references)
        reference_only = {name: line for name, line in references.items() if name not in declarations}
        groups = []
        for label, locations in (("Declaration", declarations), ("Reference", reference_only), ("Test", tests)):
            groups.append([f"{'Declaration/Reference' if name in combined else label} hint: {name}:{locations[name]}: "
                           + ("curated concern link; inspect assertions" if name in curated else f"{counts[name]} matching lines")
                           for name in sorted(locations, key=order)])
        # Interleave groups so a busy reference surface cannot bury every test or
        # declaration on the first page; pagination still covers every file hint.
        rows = [row for batch in zip_longest(*groups) for row in batch if row is not None]
        summary = (f"Matched {len(declarations)} declaration files, {len(references)} reference files, "
                   f"{len(tests)} test/support files")
        return render(rows, summary, "file hints")
    names = list(counts)
    names.sort(key=order)
    excerpts.sort(key=lambda row: (order(row[0]), row[1]))
    rows = ([f"{name}:{number}: {line}" for name, number, line in excerpts] if args.excerpts
            else [(f"{name}:{declarations[name]}: {counts[name]} matching lines (declaration hint)"
                   if name in declarations else f"{name}: {counts[name]} matching lines")
                  for name in names])
    return render(rows, f"Matched {sum(counts.values())} lines in {len(counts)} files",
                  "excerpt lines" if args.excerpts else "files")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, SyntaxError, subprocess.CalledProcessError) as error:
        print(f"Search failed: {error}", file=sys.stderr)
        print("Try: python3 Scripts/agent-search.py --help", file=sys.stderr)
        sys.exit(2)
