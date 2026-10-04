#!/usr/bin/env python3
"""Fail when AccessibilityID constants collide or UITests use raw identifier literals."""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

from internal.cli import ROOT
ID_FILE = ROOT / "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Accessibility/AccessibilityID.swift"
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
    paths = sorted({ID_FILE, *ID_FILE.parent.glob("AccessibilityID*.swift")})
    counts = Counter(value for path in paths
                     for value in STATIC_LET.findall(path.read_text(encoding="utf-8")))
    return sorted(value for value, count in counts.items() if count > 1)


def uitest_findings(allowed: set[str]) -> tuple[list[str], list[str]]:
    violations: list[str] = []
    warnings: list[str] = []
    for path in sorted(UITESTS.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT)
        for line_number, line in enumerate(text.splitlines(), start=1):
            stripped = line.lstrip()
            if stripped.startswith("//"):
                continue
            for value in RAW_QUERY.findall(line):
                if value in allowed:
                    continue
                violations.append(
                    f"{relative}:{line_number}: raw UITest identifier {value!r}; use AccessibilityID.*"
                )
        if "waitForExistence(timeout:" in text and "trinketWaitForExistence" not in text:
            if "XCTest" in text or "TrinketUITest" in text:
                warnings.append(
                    f"{relative}: use trinketWaitForExistence(timeout:) for MainActor-safe waits"
                )
    return violations, warnings


def main() -> int:
    failures = [f"duplicate AccessibilityID constant: {value}" for value in unique_constants()]
    raw, warnings = uitest_findings(allowlist())
    failures.extend(raw)
    if not failures and warnings:
        print("Accessibility ID advisory:", file=sys.stderr)
        for warning in warnings:
            print(f"  {warning}", file=sys.stderr)
    if failures:
        print("Accessibility ID check failed:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    print("Accessibility ID check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
