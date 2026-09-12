#!/usr/bin/env python3
"""Read a complete Markdown section or list its heading anchors."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from urllib.parse import unquote

from internal.markdown import headings

ROOT = Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", help="repository Markdown path, optionally followed by #heading-anchor")
    parser.add_argument("--outline", action="store_true", help="list anchors and source ranges instead of document text")
    args = parser.parse_args(argv)
    name, separator, anchor = args.target.partition("#")
    path = (root / name).resolve()
    try:
        relative = path.relative_to(root.resolve()).as_posix()
        if not name or path.suffix not in {".md", ".mdc"}:
            raise ValueError("target must be a Markdown file within the repository")
        lines = path.read_text(encoding="utf-8").splitlines()
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
    except (OSError, ValueError) as error:
        print(f"Read failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
