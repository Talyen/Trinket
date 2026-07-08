#!/usr/bin/env python3
"""Mechanical XCTest → Swift Testing migration for Trinket unit tests."""

from __future__ import annotations

import re
import sys
from pathlib import Path

SKIP_DIRS = {"TrinketUITests", "Support"}
SKIP_FILES = {
    "AppTestCase.swift",
    "TrinketUITestCase.swift",
    "SeededSmokeUITestCase.swift",
}


def camel_from_test(name: str) -> str:
    if not name.startswith("test"):
        return name[0].lower() + name[1:] if name else name
    rest = name[4:]
    if not rest:
        return "test"
    return rest[0].lower() + rest[1:]


def convert_assertions(text: str) -> str:
    # try XCTUnwrap / XCTUnwrap
    text = re.sub(r"\btry XCTUnwrap\(", "try #require(", text)
    text = re.sub(r"\bXCTUnwrap\(", "#require(", text)

    # XCTAssertFalse / XCTAssertTrue (with optional message)
    text = re.sub(
        r'XCTAssertFalse\(([^,()]+(?:\([^)]*\))?[^,()]*),\s*"([^"]*)"\)',
        r'#expect(!\1, "\2")',
        text,
    )
    text = re.sub(
        r"XCTAssertFalse\(([^,()]+(?:\([^)]*\))?[^,()]*),\s*file:\s*([^,]+),\s*line:\s*([^)]+)\)",
        r"#expect(!\1, file: \2, line: \3)",
        text,
    )
    text = re.sub(r"XCTAssertFalse\(([^)]+)\)", r"#expect(!(\1))", text)
    text = re.sub(
        r'XCTAssertTrue\(([^,()]+(?:\([^)]*\))?[^,()]*),\s*"([^"]*)"\)',
        r'#expect(\1, "\2")',
        text,
    )
    text = re.sub(r"XCTAssertTrue\(([^)]+)\)", r"#expect(\1)", text)

    # XCTAssertNil / XCTAssertNotNil (with optional message)
    text = re.sub(
        r'XCTAssertNil\(([^,()]+(?:\([^)]*\))?[^,()]*),\s*"([^"]*)"\)',
        r'#expect(\1 == nil, "\2")',
        text,
    )
    text = re.sub(r"XCTAssertNil\(([^)]+)\)", r"#expect(\1 == nil)", text)
    text = re.sub(
        r'XCTAssertNotNil\(([^,()]+(?:\([^)]*\))?[^,()]*),\s*"([^"]*)"\)',
        r'#expect(\1 != nil, "\2")',
        text,
    )
    text = re.sub(r"XCTAssertNotNil\(([^)]+)\)", r"#expect(\1 != nil)", text)

    # XCTAssertEqual with accuracy
    def accuracy_repl(m: re.Match[str]) -> str:
        a, b, acc = m.group(1), m.group(2), m.group(3)
        return f"#expect(abs(({a}) - ({b})) < {acc})"

    text = re.sub(
        r"XCTAssertEqual\(([^,]+),\s*([^,]+),\s*accuracy:\s*([^)]+)\)",
        accuracy_repl,
        text,
    )

    # XCTAssertEqual / XCTAssertNotEqual
    text = re.sub(r"XCTAssertEqual\(([^,]+),\s*([^)]+)\)", r"#expect(\1 == \2)", text)
    text = re.sub(
        r"XCTAssertNotEqual\(([^,]+),\s*([^)]+)\)", r"#expect(\1 != \2)", text
    )

    # Comparison asserts
    for op, sym in [
        ("GreaterThanOrEqual", ">="),
        ("LessThanOrEqual", "<="),
        ("GreaterThan", ">"),
        ("LessThan", "<"),
    ]:
        text = re.sub(
            rf"XCTAssert{op}\(([^,]+),\s*([^)]+)\)",
            rf"#expect(\1 {sym} \2)",
            text,
        )

    # XCTAssertIdentical
    text = re.sub(
        r"XCTAssertIdentical\(([^,]+),\s*([^)]+)\)", r"#expect(\1 === \2)", text
    )
    text = re.sub(
        r"XCTAssertNotIdentical\(([^,]+),\s*([^)]+)\)", r"#expect(\1 !== \2)", text
    )

    # XCTFail
    text = re.sub(r'XCTFail\("([^"]*)"\)', r'Issue.record("\1")', text)
    text = re.sub(r"XCTFail\(([^)]+)\)", r"Issue.record(\1)", text)

    return text


def convert_class_declaration(text: str, *, main_actor: bool) -> str:
    # Remove @MainActor from class line temporarily
    had_main = "@MainActor" in text.split("final class")[0] if "final class" in text else False
  # handled separately

    patterns = [
        (r"@MainActor\s+final class (\w+): XCTestCase", r"@Suite @MainActor\nfinal class \1"),
        (r"@MainActor\s+class (\w+): XCTestCase", r"@Suite @MainActor\nfinal class \1"),
        (r"final class (\w+): XCTestCase", r"@Suite\nstruct \1"),
        (r"class (\w+): XCTestCase", r"@Suite\nstruct \1"),
    ]
    for pat, repl in patterns:
        if re.search(pat, text):
            text = re.sub(pat, repl, text, count=1)
            break
    return text


def convert_setup_teardown(text: str) -> str:
    # setUp async
    text = re.sub(
        r"override func setUp\(\) async throws \{[^}]*try await super\.setUp\(\)[^}]*\}",
        "",
        text,
        flags=re.DOTALL,
    )
    text = re.sub(
        r"override func tearDown\(\) async throws \{[^}]*try await super\.tearDown\(\)[^}]*\}",
        "",
        text,
        flags=re.DOTALL,
    )
    text = re.sub(
        r"override func setUpWithError\(\) throws \{[^}]*try super\.setUpWithError\(\)[^}]*\}",
        "",
        text,
        flags=re.DOTALL,
    )
    text = re.sub(
        r"override func tearDownWithError\(\) throws \{[^}]*try super\.tearDownWithError\(\)[^}]*\}",
        "",
        text,
        flags=re.DOTALL,
    )
    return text


def convert_test_methods(text: str) -> str:
    def repl(m: re.Match[str]) -> str:
        indent, name, params = m.group(1), m.group(2), m.group(3) or ""
        new_name = camel_from_test(name)
        async_part = ""
        if " async " in params or params.strip().startswith("async"):
            async_part = " async"
        throws_part = ""
        if " throws" in params:
            throws_part = " throws"
        return f"{indent}@Test func {new_name}(){async_part}{throws_part}"

    return re.sub(
        r"^(\s*)func (test\w+)\(([^)]*)\)",
        repl,
        text,
        flags=re.MULTILINE,
    )


def migrate_file(path: Path) -> bool:
    if path.name in SKIP_FILES:
        return False
    if any(part in SKIP_DIRS for part in path.parts):
        return False
    if "TrinketUITests" in str(path):
        return False

    original = path.read_text()
    if "import XCTest" not in original:
        return False
    if "import Testing" in original and "import XCTest" not in original:
        return False

    text = original
    text = text.replace("import XCTest\n", "import Testing\n")
    text = convert_class_declaration(text, main_actor="@MainActor" in original)
    text = convert_setup_teardown(text)
    text = convert_test_methods(text)
    text = convert_assertions(text)

    # Drop XCTestCase-only patterns
    text = re.sub(r"\bcontinueAfterFailure\s*=\s*false\n?", "", text)

    if text != original:
        path.write_text(text)
        return True
    return False


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    targets = [
        root / "TrinketTests",
        *list((root / "Packages").glob("*/Tests")),
    ]
    migrated = 0
    for base in targets:
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.swift")):
            if migrate_file(path):
                migrated += 1
                print(f"migrated: {path.relative_to(root)}")
    print(f"Total migrated: {migrated}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
