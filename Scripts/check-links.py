#!/usr/bin/env python3
"""Check repository documentation for broken local links."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

from internal.markdown import heading_slugs, unfenced_lines
from internal.cli import ROOT
from internal.doc_diagnostics import report_failures
SKIP_PARTS = {".git", ".DerivedData", ".tools", ".build", "Generated", "BalanceSweepReports"}
LINK_START = re.compile(r"\[[^\]]*\]\(\s*")


def link_targets(lines: list[str]):
    """Read inline destinations outside fences/code, preserving balanced parentheses."""
    visible = dict(unfenced_lines(lines))
    text = '\n'.join(visible.get(number, '') for number in range(1, len(lines) + 1))
    # Code spans can cross physical lines. Only an equal-length backtick run closes one.
    masked = list(text)
    for paragraph in re.finditer(r'\S.*?(?=\n[ \t]*\n|\Z)', text, re.S):
        runs = list(re.finditer(r'`+', paragraph[0]))
        index = 0
        while index < len(runs):
            opening = runs[index]
            prefix = paragraph[0][:opening.start()]
            escaped = (len(prefix) - len(prefix.rstrip('\\'))) % 2
            closing = None if escaped else next((other for other in range(index + 1, len(runs))
                                                if len(runs[other][0]) == len(opening[0])), None)
            if closing is None:
                index += 1
                continue
            for offset in range(paragraph.start() + opening.start(), paragraph.start() + runs[closing].end()):
                if masked[offset] != '\n':
                    masked[offset] = ' '
            index = closing + 1
    text = ''.join(masked)
    for match in LINK_START.finditer(text):
        start = end = match.end()
        if start < len(text) and text[start] == '<':
            end = text.find('>', start + 1)
            if end < 0:
                continue
            target = text[start + 1:end]
            end += 1
        else:
            depth = 0
            while end < len(text):
                character = text[end]
                if character == '\\' and end + 1 < len(text):
                    end += 2
                    continue
                if character == '(':
                    depth += 1
                elif character == ')':
                    if depth == 0:
                        break
                    depth -= 1
                elif character.isspace():
                    break
                end += 1
            if depth:
                continue
            target = text[start:end]
        if not re.match(r'(?:\s+(?:"[^"\n]*"|\'[^\'\n]*\'|\([^\n]*?\)))?\s*\)', text[end:]):
            continue
        yield text.count('\n', 0, match.start()) + 1, re.sub(r'\\([\\()<>])', r'\1', target)


def markdown_files() -> list[Path]:
    """Return tracked and untracked authored Markdown while respecting ignores."""
    if (ROOT / ".git").exists():
        result = subprocess.run(
            ["git", "-C", str(ROOT), "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "*.md"],
            capture_output=True, text=True, check=True,
        )
        return sorted(
            ROOT / name for name in set(result.stdout.split("\0"))
            if name and not SKIP_PARTS.intersection(Path(name).parts) and (ROOT / name).is_file()
        )

    # Keep the checker usable from a source export without a Git metadata
    # directory. The normal repository path above is deliberately narrower.
    return sorted(
        path
        for path in ROOT.rglob("*.md")
        if path.is_file() and not SKIP_PARTS.intersection(path.relative_to(ROOT).parts)
    )


def broken_links(files: list[Path]) -> list[str]:
    failures: list[str] = []
    slug_cache: dict[Path, set[str]] = {}
    resolved_root = ROOT.resolve()
    for source in files:
        for line_number, target in link_targets(source.read_text(encoding="utf-8").splitlines()):
            if not target or re.match(r"[A-Za-z][A-Za-z0-9+.-]*:", target):
                continue
            path_text, _, fragment = target.partition("#")
            path_text, fragment = unquote(path_text), unquote(fragment)
            if path_text:
                resolved = (source.parent / path_text).resolve()
                if not resolved.exists():
                    failures.append(
                        f"{source.relative_to(ROOT)}:{line_number}: missing link target {path_text}"
                    )
                    continue
            else:
                resolved = source
            if not fragment:
                continue
            if resolved.is_dir():
                resolved = resolved / "README.md"
            if resolved.suffix != ".md" or not resolved.is_file():
                continue
            if resolved not in slug_cache:
                slug_cache[resolved] = heading_slugs(resolved)
            slugs = slug_cache[resolved]
            if fragment not in slugs:
                destination = resolved.relative_to(resolved_root) if resolved.is_relative_to(resolved_root) else resolved
                failures.append(
                    f"{source.relative_to(ROOT)}:{line_number}: missing heading {destination}#{fragment}"
                )
    return failures


def affected_documents(files: list[Path], paths: set[Path]) -> list[Path]:
    """Check edited documents and inbound links to changed/deleted targets."""
    affected = set(paths)
    selected = []
    for source in files:
        if source.resolve() in affected:
            selected.append(source)
            continue
        for _, target in link_targets(source.read_text(encoding='utf-8').splitlines()):
            target = target.partition('#')[0]
            if target and not re.match(r'[A-Za-z][A-Za-z0-9+.-]*:', target):
                resolved = (source.parent / unquote(target)).resolve()
                if (resolved / 'README.md' if resolved.is_dir() else resolved) not in affected:
                    continue
                selected.append(source)
                break
    return selected


def main() -> int:
    if sys.argv[1:]:
        print(f"Usage: {Path(sys.argv[0]).name}", file=sys.stderr)
        return 2
    files = markdown_files()
    failures = broken_links(files)
    if failures:
        report_failures("Documentation link checks failed:", failures, root=ROOT)
        return 1
    print(f"Documentation links passed ({len(files)} Markdown files).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
