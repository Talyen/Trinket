#!/usr/bin/env python3
"""Check repository documentation for broken local links and known drift."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
SKIP_PARTS = {".git", ".DerivedData", ".tools", ".build", "Generated"}
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def markdown_files() -> list[Path]:
    return sorted(
        path
        for path in ROOT.rglob("*.md")
        if not SKIP_PARTS.intersection(path.relative_to(ROOT).parts)
    )


def broken_links(files: list[Path]) -> list[str]:
    failures: list[str] = []
    for source in files:
        for line_number, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
            for raw in LINK.findall(line):
                target = raw.strip().split(maxsplit=1)[0].strip("<>")
                if not target or target.startswith(("#", "http://", "https://", "mailto:")):
                    continue
                path_text = unquote(target.split("#", 1)[0])
                if not path_text:
                    continue
                resolved = (source.parent / path_text).resolve()
                if not resolved.exists():
                    failures.append(
                        f"{source.relative_to(ROOT)}:{line_number}: missing link target {path_text}"
                    )
    return failures


def structural_checks(files: list[Path]) -> list[str]:
    failures: list[str] = []
    relative = {path.relative_to(ROOT) for path in files}

    for manifest in sorted((ROOT / "Packages").glob("*/Package.swift")):
        package = manifest.parent.relative_to(ROOT)
        if package / "README.md" not in relative and package / "AGENTS.md" not in relative:
            failures.append(f"{package}: package has neither README.md nor AGENTS.md")

    plan = json.loads((ROOT / "Smoke.xctestplan").read_text(encoding="utf-8"))
    selected = {
        test
        for target in plan["testTargets"]
        for test in target.get("selectedTests", [])
    }
    ui_source = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((ROOT / "TrinketUITests").rglob("*.swift"))
    )
    for test_class in sorted(selected):
        if not re.search(rf"\b(?:final\s+)?class\s+{re.escape(test_class)}\b", ui_source):
            failures.append(f"Smoke.xctestplan: selected class {test_class} is not declared")

    stale = {
        "five-surface selector matrix": "smoke plan now covers six surfaces",
        "BattleRuntimeSession": "runtime owner is BattleRuntime/BattleSession",
    }
    for source in files:
        text = source.read_text(encoding="utf-8")
        for phrase, explanation in stale.items():
            if phrase in text:
                failures.append(f"{source.relative_to(ROOT)}: stale phrase {phrase!r} ({explanation})")
    return failures


def main() -> int:
    files = markdown_files()
    failures = broken_links(files) + structural_checks(files)
    if failures:
        print("Documentation checks failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1
    print(f"Documentation checks passed ({len(files)} Markdown files).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
