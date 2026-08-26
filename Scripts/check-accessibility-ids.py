#!/usr/bin/env python3
"""Fail when AccessibilityID constants collide or UITests use raw identifier literals."""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ID_FILE = ROOT / "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/AccessibilityID.swift"
UITESTS = ROOT / "TrinketUITests"
ALLOWLIST_FILE = ROOT / "Scripts/config/uitest-system-query-allowlist.txt"

STATIC_LET = re.compile(
    r"public static let [A-Za-z_][A-Za-z0-9_]*\s*=\s*\"([^\"]+)\""
)
RAW_QUERY = re.compile(
    r'(?:buttons|staticTexts|textFields|otherElements|images|cells|navigationBars|tabBars|alerts|descendants\([^)]*\))\s*\[\s*"([^"]+)"'
)


def allowlist() -> set[str]:
    if not ALLOWLIST_FILE.is_file():
        return set()
    values: set[str] = set()
    for line in ALLOWLIST_FILE.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            values.add(stripped)
    return values


def unique_constants() -> list[str]:
    text = ID_FILE.read_text(encoding="utf-8")
    found = STATIC_LET.findall(text)
    grouped: dict[str, int] = defaultdict(int)
    for value in found:
        grouped[value] += 1
    return sorted(value for value, count in grouped.items() if count > 1)


def raw_uitest_literals(allowed: set[str]) -> list[str]:
    violations: list[str] = []
    for path in sorted(UITESTS.rglob("*.swift")):
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            stripped = line.lstrip()
            if stripped.startswith("//"):
                continue
            for value in RAW_QUERY.findall(line):
                if value in allowed:
                    continue
                if "AccessibilityID." in line:
                    continue
                relative = path.relative_to(ROOT)
                violations.append(
                    f"{relative}:{line_number}: raw UITest identifier {value!r}; use AccessibilityID.*"
                )
    return violations


def main() -> int:
    failures = [f"duplicate AccessibilityID constant: {value}" for value in unique_constants()]
    failures.extend(raw_uitest_literals(allowlist()))
    if failures:
        print("Accessibility ID check failed:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    print("Accessibility ID check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
