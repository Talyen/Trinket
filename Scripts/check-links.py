#!/usr/bin/env python3
"""Check repository documentation for broken local links."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

from internal.markdown import heading_slugs, unfenced_lines

ROOT = Path(__file__).resolve().parent.parent
SKIP_PARTS = {".git", ".DerivedData", ".tools", ".build", "Generated", "BalanceSweepReports"}
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def markdown_files() -> list[Path]:
    """Return tracked and untracked authored Markdown while respecting ignores."""
    result = subprocess.run(
        [
            "git",
            "-C",
            str(ROOT),
            "ls-files",
            "--cached",
            "--",
            "*.md",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0 and (ROOT / ".git").exists():
        authored = set(result.stdout.splitlines())
        untracked = subprocess.run(
            [
                "git",
                "-C",
                str(ROOT),
                "ls-files",
                "--others",
                "--exclude-standard",
                "--",
                "*.md",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if untracked.returncode == 0:
            authored.update(untracked.stdout.splitlines())
        return sorted(
            ROOT / line
            for line in authored
            if line
            and not SKIP_PARTS.intersection(Path(line).parts)
            and (ROOT / line).is_file()
        )

    # Keep the checker usable from a source export without a Git metadata
    # directory. The normal repository path above is deliberately narrower.
    return sorted(
        path
        for path in ROOT.rglob("*.md")
        if not SKIP_PARTS.intersection(path.relative_to(ROOT).parts)
    )


def broken_links(files: list[Path]) -> list[str]:
    failures: list[str] = []
    slug_cache: dict[Path, set[str]] = {}
    for source in files:
        for line_number, line in unfenced_lines(source.read_text(encoding="utf-8").splitlines()):
            for raw in LINK.findall(line):
                target = raw.strip().split(maxsplit=1)[0].strip("<>")
                if not target or target.startswith(("http://", "https://", "mailto:")):
                    continue
                path_text, _, fragment = unquote(target).partition("#")
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
                    failures.append(
                        f"{source.relative_to(ROOT)}:{line_number}: missing heading #{fragment}"
                    )
    return failures


def main() -> int:
    for argument in sys.argv[1:]:
        print(f"Usage: {Path(sys.argv[0]).name}", file=sys.stderr)
        return 2
    files = markdown_files()
    failures = broken_links(files)
    if failures:
        print("Documentation link checks failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1
    print(f"Documentation links passed ({len(files)} Markdown files).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
