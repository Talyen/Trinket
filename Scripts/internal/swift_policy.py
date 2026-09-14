#!/usr/bin/env python3
"""Scan Swift policy candidates; shell entrypoints own violation reporting."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
API_BANS = {
    "NavigationView": "Use NavigationStack instead of NavigationView",
    "ObservableObject": "Use @Observable instead of ObservableObject",
    "@Published": "Use @Observable properties instead of @Published",
    "@StateObject": "Use @Observable + @Environment(Type.self) instead of @StateObject",
    "@EnvironmentObject": "Use @Environment(Type.self) instead of @EnvironmentObject",
    "@ObservedObject": "Use @Bindable / @Environment(Type.self) instead of @ObservedObject",
}
XCTEST_MESSAGE = "Use Swift Testing instead of XCTest outside TrinketUITests"
REASON_MESSAGE = "swiftlint:disable must include ' - <reason>'"
DISABLE = re.compile(r"^\s*swiftlint:disable\b")
REASON = re.compile(r"\s+-\s+\S")


def is_package_test(path: Path) -> bool:
    return path.parts[0] == "Packages" and "Tests" in path.parts and "TrinketUITests" not in path.parts


def candidate_paths(check: str, paths: list[str], root: Path) -> list[Path]:
    pattern = (
        "|".join([*API_BANS, "XCTest", "XCTAssert", "XCTFail", "XCTUnwrap"])
        if check == "api-bans" else "swiftlint:disable"
    )
    exclusions = ["--glob", "!**/Generated/**"] if check == "swiftlint-reasons" else []
    result = subprocess.run(
        ["rg", "--files-with-matches", "--null", "--glob", "*.swift", *exclusions, pattern, "--", *paths],
        cwd=root, capture_output=True, text=True,
    )
    if result.returncode not in (0, 1):
        raise RuntimeError(f"Policy search failed (rg exit {result.returncode}): {result.stderr.strip()}")
    candidates = {root / path for path in result.stdout.split("\0") if path}
    return sorted(path for path in candidates if "Generated" not in path.relative_to(root).parts
                  or is_package_test(path.relative_to(root)))


def formatter_tokens(source: str, root: Path) -> list[dict]:
    pins = (root / "Scripts/tool-versions.env").read_text(encoding="utf-8")
    expected = re.search(r"^SWIFTFORMAT_VERSION=(\S+)$", pins, re.MULTILINE)
    if expected is None:
        raise RuntimeError("SWIFTFORMAT_VERSION is missing from Scripts/tool-versions.env")
    pinned = root / ".tools/swiftformat"
    binary = str(pinned) if pinned.is_file() else shutil.which("swiftformat")
    if binary is None:
        raise RuntimeError("SwiftFormat is missing; run ./Scripts/ensure-ci-tools.sh")
    result = subprocess.run(
        [binary, "stdin", "--disable", "all", "--output-tokens", "--quiet", "--cache", "ignore"],
        input=source, capture_output=True, text=True, cwd=root,
    )
    if result.returncode:
        raise RuntimeError(f"SwiftFormat tokenization failed (exit {result.returncode}): {result.stderr.strip()}")
    try:
        payload = json.loads(result.stdout)
        tokens = payload["tokens"]
        if payload["version"] != expected.group(1):
            raise RuntimeError(f"SwiftFormat version mismatch: expected {expected.group(1)}, found {payload['version']}")
        if not isinstance(tokens, list) or any(
            not isinstance(token["type"], str) or not isinstance(token["string"], str)
            or token["type"] == "error" for token in tokens
        ):
            raise ValueError("invalid token stream")
        # The exporter must describe the original source, even around directives.
        if "".join(token["string"] for token in tokens) != source:
            raise ValueError("token export changed the source")
    except (ValueError, KeyError, TypeError) as error:
        raise RuntimeError(f"Invalid SwiftFormat token export: {error}") from error
    return tokens


def violations(check: str, tokens: list[dict], path: Path) -> list[tuple[int, str]]:
    findings: list[tuple[int, str]] = []
    package_test = is_package_test(path)
    line = 1
    line_comment: str | None = None
    comment_line = 1
    block_depth = 0
    for token in tokens:
        kind, text = token["type"], token["string"]
        if kind == "startOfScope" and text == "/*":
            block_depth += 1
        elif kind == "endOfScope" and text == "*/":
            block_depth -= 1
        elif kind == "startOfScope" and text == "//" and block_depth == 0:
            line_comment = ""
            comment_line = line
        elif line_comment is not None and kind != "linebreak":
            line_comment += text

        if check == "api-bans" and kind in ("identifier", "keyword") and not block_depth and line_comment is None:
            name = text.strip("`")
            if "Generated" not in path.parts and name in API_BANS:
                findings.append((line, API_BANS[name]))
            if package_test and (name in ("XCTest", "XCTestCase", "XCTFail", "XCTUnwrap") or name.startswith("XCTAssert")):
                findings.append((line, XCTEST_MESSAGE))

        if kind == "linebreak":
            if check == "swiftlint-reasons" and line_comment is not None and DISABLE.match(line_comment) and not REASON.search(line_comment):
                findings.append((comment_line, REASON_MESSAGE))
            line_comment = None
            line += 1
    if check == "swiftlint-reasons" and line_comment is not None and DISABLE.match(line_comment) and not REASON.search(line_comment):
        findings.append((comment_line, REASON_MESSAGE))
    return sorted(set(findings))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("check", choices=("api-bans", "swiftlint-reasons"))
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    try:
        for path in candidate_paths(args.check, args.paths, ROOT):
            relative = path.relative_to(ROOT)
            try:
                tokens = formatter_tokens(path.read_text(encoding="utf-8"), ROOT)
            except (OSError, RuntimeError, ValueError) as error:
                raise RuntimeError(f"{relative}: {error}") from error
            for line, message in violations(args.check, tokens, relative):
                print(f"{relative}:{line}: {message}")
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Swift policy scan failed: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
