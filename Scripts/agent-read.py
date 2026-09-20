#!/usr/bin/env python3
"""Read Markdown sections, source line ranges, or declaration-location outlines."""

from __future__ import annotations

import argparse
import ast
import sys
from pathlib import Path
from urllib.parse import unquote

from internal.markdown import headings
from internal.cli import ROOT


def source_outline(path: Path, source: str) -> list[tuple[int, str]]:
    if path.suffix == ".py":
        tree = ast.parse(source)
        return sorted((node.lineno, f"{type(node).__name__} {node.name}") for node in ast.walk(tree)
                      if isinstance(node, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)))
    from internal.swift_policy import formatter_tokens
    tokens = formatter_tokens(source, ROOT)
    lines = source.splitlines()
    declarations = {"struct", "class", "enum", "actor", "protocol", "extension", "func", "typealias", "init", "deinit", "subscript", "var", "let"}
    found = {}
    line = 1
    for index, token in enumerate(tokens):
        kind, value = token["type"], token["string"]
        if kind == "keyword" and value in declarations:
            following = next((entry for entry in tokens[index + 1:] if entry["type"] not in {"space", "linebreak"}), None)
            if value != "class" or not following or following["string"] not in {"func", "var", "subscript"}:
                found[line] = lines[line - 1].strip()
        line += value.count("\n")
    return sorted(found.items())


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", help="repository Markdown path, optionally followed by #heading-anchor")
    parser.add_argument("--outline", action="store_true", help="list anchors and source ranges instead of document text")
    parser.add_argument("--lines", help="explicit inclusive source range START:END")
    parser.add_argument("--offset", type=int, default=0, help="source-outline entry offset")
    parser.add_argument("--limit", type=int, default=60, help="source-outline page length")
    args = parser.parse_args(argv)
    name, separator, anchor = args.target.partition("#")
    path = (root / name).resolve()
    try:
        relative = path.relative_to(root.resolve()).as_posix()
        if not name or path.suffix not in {".md", ".mdc", ".swift", ".py"}:
            raise ValueError("target must be Markdown, Swift, or Python within the repository")
        source = path.read_text(encoding="utf-8")
        lines = source.splitlines()
        if args.lines:
            if separator or args.outline:
                raise ValueError("--lines cannot be combined with an anchor or --outline")
            start, end = map(int, args.lines.split(":"))
            if not 1 <= start <= end <= len(lines):
                raise ValueError("line range must be within the file")
            print(f"{relative}:{start}-{end} (requested range; not a completeness claim)")
            for number in range(start, end + 1):
                print(f"{number}: {lines[number - 1]}")
            return 0
        if path.suffix in {".swift", ".py"}:
            if separator or not args.outline or args.offset < 0 or args.limit < 1:
                raise ValueError("source files require --outline or --lines START:END; outline bounds must be nonnegative/positive")
            entries = source_outline(path, source)
            if args.offset > len(entries):
                raise ValueError("--offset is beyond the last outline entry")
            stop = min(len(entries), args.offset + args.limit)
            print("Declaration hints only; includes local declarations. Read surrounding attributes, callers, and complete bodies.")
            for number, declaration in entries[args.offset:stop]:
                print(f"{relative}:{number}: {declaration[:240]}")
                if len(declaration) > 240:
                    print("  … declaration line shortened; read the source range")
            print(f"Entries {args.offset}:{stop} of {len(entries)}; omitted {max(0, len(entries) - stop)} after this page.")
            if stop < len(entries):
                import shlex
                print("Continue: " + shlex.join(["python3", "Scripts/agent-read.py", relative, "--outline", "--offset", str(stop), "--limit", str(args.limit)]))
            return 0
        entries = headings(lines)
        selected = None
        if separator:
            selected = next((entry for entry in entries if entry.slug == unquote(anchor)), None)
            if selected is None:
                raise ValueError(f"missing heading #{anchor}; use --outline {name}")
        start, end = (selected.start, selected.end) if selected else (1, len(lines))
        if args.outline:
            for entry in entries:
                if start <= entry.start <= end:
                    print(f"{relative}#{entry.slug} [{entry.start}-{entry.end}] {'#' * entry.level} {entry.title}")
        else:
            print(f"{relative}:{start}-{end} (complete {'section' if selected else 'document'})")
            if selected and selected.parents:
                print("Parent headings:")
                for index in selected.parents:
                    parent = entries[index]
                    print(f"{parent.start}: {lines[parent.start - 1]}")
            for number in range(start, end + 1):
                print(f"{number}: {lines[number - 1]}")
        return 0
    except (OSError, ValueError, RuntimeError, SyntaxError) as error:
        print(f"Read failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
