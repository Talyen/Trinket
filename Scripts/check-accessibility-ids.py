#!/usr/bin/env python3
"""Fail when AccessibilityID constants collide or UITests use raw identifier literals."""

from __future__ import annotations

import re
import sys
from collections import Counter

from internal.cli import ROOT
from internal.source_declarations import swift_code_tokens
ID_FILE = ROOT / "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Accessibility/AccessibilityID.swift"
UITESTS = ROOT / "TrinketUITests"
ALLOWLIST_FILE = ROOT / "Scripts/config/uitest-system-query-allowlist.txt"

QUERY_NAMES = {'buttons', 'staticTexts', 'textFields', 'otherElements', 'images', 'cells',
               'navigationBars', 'tabBars', 'alerts'}


def literal_value(source: str, tokens: list, index: int) -> str | None:
    if tokens[index][0] != 'literal' or tokens[index][1] != '<string>':
        return None
    end = tokens[index + 1][4] if index + 1 < len(tokens) else len(source)
    literal = source[tokens[index][4]:end].strip()
    match = re.match(r'(?P<hashes>#{0,})"([^"\\\n]*)"(?P=hashes)', literal)
    return match[2] if match else None


def raw_queries(source: str):
    tokens = swift_code_tokens(source)
    for index, (_, value, line, _, _) in enumerate(tokens):
        if value != '[' or index + 2 >= len(tokens) or tokens[index + 2][1] != ']':
            continue
        previous = index - 1
        if previous >= 0 and tokens[previous][1] == ')':
            depth = 1
            previous -= 1
            while previous >= 0 and depth:
                depth += (tokens[previous][1] == ')') - (tokens[previous][1] == '(')
                previous -= 1
            query = previous >= 0 and tokens[previous][1] == 'descendants'
        else:
            query = previous >= 0 and tokens[previous][1] in QUERY_NAMES
        if query and (value := literal_value(source, tokens, index + 1)) is not None:
            yield line, value


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
    counts = Counter()
    for path in paths:
        source = path.read_text(encoding='utf-8')
        tokens = swift_code_tokens(source)
        for index in range(len(tokens) - 5):
            if [token[1] for token in tokens[index:index + 3]] != ['public', 'static', 'let']:
                continue
            if tokens[index + 4][1] == '=' and (value := literal_value(source, tokens, index + 5)) is not None:
                counts[value] += 1
    return sorted(value for value, count in counts.items() if count > 1)


def uitest_findings(allowed: set[str]) -> tuple[list[str], list[str]]:
    violations: list[str] = []
    warnings: list[str] = []
    for path in sorted(UITESTS.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT)
        if any(name in text for name in (*QUERY_NAMES, 'descendants')):
            for line_number, value in raw_queries(text):
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
