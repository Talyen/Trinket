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
LINK = re.compile(r"\[[^\]]*\]\(\s*(<[^>]*>|[^\s)]*)(?:\s+[^)]*)?\)")


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
        for line_number, line in unfenced_lines(source.read_text(encoding="utf-8").splitlines()):
            for raw in LINK.findall(line):
                target = raw.strip("<>")
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
