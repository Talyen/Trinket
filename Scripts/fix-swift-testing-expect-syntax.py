#!/usr/bin/env python3
"""Repair malformed #expect lines from mechanical XCTest migration."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEST_GLOBS = [
    "TrinketTests/**/*.swift",
    "Packages/*/Tests/**/*.swift",
]


def fix_expect_nil_inside_call(text: str) -> str:
    # foo(bar == nil) -> foo(bar) == nil
    return re.sub(
        r"#expect\(([^#\n]+?) == nil\)\)",
        r"#expect(\1) == nil)",
        text,
    )


def fix_expect_comma_expected(text: str) -> str:
    # #expect(expr with == inside args).suffix, expected) -> #expect(expr.fixed.suffix == expected)
    def repl(m: re.Match[str]) -> str:
        expr = m.group(1)
        expected = m.group(2).strip()
        fixed = fix_expr_equals_in_args(expr)
        return f"#expect({fixed} == {expected})"

    return re.sub(
        r"#expect\(([^#\n]+?)\),\s*([^)\n]+)\)\s*$",
        repl,
        text,
        flags=re.MULTILINE,
    )


def fix_expr_equals_in_args(expr: str) -> str:
    # label: value == otherLabel: value -> label: value, otherLabel: value
    while True:
        updated = re.sub(
            r"([\.\(,\s])([A-Za-z_][\w]*):\s*([^=,)]+?)\s*==\s*([A-Za-z_][\w]*):\s*",
            r"\1\2: \3, \4: ",
            expr,
        )
        if updated == expr:
            break
        expr = updated

    # (.enumCase == value, -> (.enumCase, value,
    while True:
        updated = re.sub(
            r"\(\.([A-Za-z_][\w]*)\s*==\s*([^),]+),\s*",
            r"(.\1, \2, ",
            expr,
        )
        if updated == expr:
            break
        expr = updated

    # (numeric == numeric) at end of paren groups - e.g. marked(2 == 6)
    expr = re.sub(r"\((\d+(?:\.\d+)?)\s*==\s*(\d+(?:\.\d+)?)\)", r"(\1, \2)", expr)

    # for: identifier == nil inside call already handled

    return expr


def fix_file(path: Path) -> bool:
    original = path.read_text()
    text = original
    text = fix_expect_nil_inside_call(text)
    text = fix_expect_comma_expected(text)
    if text != original:
        path.write_text(text)
        return True
    return False


def main() -> int:
    changed: list[Path] = []
    for pattern in TEST_GLOBS:
        for path in sorted(ROOT.glob(pattern)):
            if fix_file(path):
                changed.append(path)
    for path in changed:
        print(f"fixed: {path.relative_to(ROOT)}")
    print(f"Updated {len(changed)} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
