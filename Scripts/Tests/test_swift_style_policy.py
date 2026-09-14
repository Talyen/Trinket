#!/usr/bin/env python3
"""Behavioral contracts for the pinned formatter, linter, and portable policies."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from script_test_support import ROOT, load_script


class SwiftStylePolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.policy = load_script("swift_policy", "internal/swift_policy.py")

    def scan(self, source: str, check: str = "api-bans", path: str = "Trinket/Probe.swift"):
        tokens = self.policy.formatter_tokens(source, ROOT)
        return self.policy.violations(check, tokens, Path(path))

    def test_api_bans_distinguish_prose_from_code_and_keep_source_lines(self) -> None:
        source = '''// ObservableObject @Published NavigationView
/// @StateObject NavigationView
/* NavigationView /* ObservableObject */ @ObservedObject */
let ordinary = "NavigationView and @EnvironmentObject"
let raw = #"NavigationView \\(ObservableObject)"#
let multiline = """
NavigationView
@StateObject
"""
let interpolated = "result: \\(NavigationView { Text("probe") })"
let rawInterpolated = #"result: \\#(NavigationView { Text("probe") })"#
class Model: ObservableObject {
    @Published var count = 0
}
@StateObject var model = Model()
@ObservedObject var observed = Model()
@EnvironmentObject var environment: Model
let namesake = NavigationViewModel()
let escaped = `NavigationView` { Text("probe") }
'''
        self.assertEqual(
            self.scan(source),
            [(10, self.policy.API_BANS["NavigationView"]),
             (11, self.policy.API_BANS["NavigationView"]),
             (12, self.policy.API_BANS["ObservableObject"]),
             (13, self.policy.API_BANS["@Published"]),
             (15, self.policy.API_BANS["@StateObject"]),
             (16, self.policy.API_BANS["@ObservedObject"]),
             (17, self.policy.API_BANS["@EnvironmentObject"]),
             (19, self.policy.API_BANS["NavigationView"])],
        )

    def test_xctest_policy_stays_scoped_to_package_tests(self) -> None:
        source = '''// import XCTest; XCTAssertTrue is discussed here.
let sample = "XCTFail"
import XCTest
class Probe: XCTestCase {
    func testProbe() { XCTAssertEqual(1, 1) }
}
'''
        self.assertEqual(self.scan(source, path="TrinketUITests/Probe.swift"), [])
        self.assertEqual(self.scan(source, path="Packages/Probe/Sources/Probe.swift"), [])
        self.assertEqual(
            self.scan(source, path="Packages/Probe/Tests/ProbeTests/Probe.swift"),
            [(line, self.policy.XCTEST_MESSAGE) for line in (3, 4, 5)],
        )
        self.assertEqual(
            self.scan(source, path="Packages/Probe/Tests/Generated/Probe.swift"),
            [(line, self.policy.XCTEST_MESSAGE) for line in (3, 4, 5)],
        )

    def test_disable_reasons_belong_to_the_actual_directive(self) -> None:
        cases = (
            ("// swiftlint:disable:next force_try\nlet value = try! load()\n", [1]),
            ("// swiftlint:disable:next force_try - \nlet value = try! load()\n", [1]),
            ("let note = \" - explanation\" // swiftlint:disable:this force_try\n", [1]),
            ("// swiftlint:disable force_try -\t  \n// rationale on another line\n", [1]),
            ("// swiftlint:disable force_try - fixture owns the invariant", []),
            ("let value = try! load() // swiftlint:disable:this force_try - fixture\n", []),
            ("// swiftlint:disable:previous force_try - fixture\n", []),
            ("let sample = \"// swiftlint:disable force_try\"\n", []),
            ("/// swiftlint:disable force_try\n", []),
            ("/* // swiftlint:disable force_try */\n", []),
            ("// This describes swiftlint:disable force_try.\n", []),
            ("// swiftlint:disable force_try", [1]),
        )
        for source, lines in cases:
            with self.subTest(source=source):
                self.assertEqual(
                    self.scan(source, "swiftlint-reasons"),
                    [(line, self.policy.REASON_MESSAGE) for line in lines],
                )

    def test_api_entrypoint_enforces_tokens_exclusions_and_diagnostics(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("check-api-bans.sh", "lib/rg-check.sh", "internal/swift_policy.py", "tool-versions.env"):
                target = root / "Scripts" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, target)
            (root / ".tools").symlink_to(ROOT / ".tools", target_is_directory=True)
            for name in ("Trinket", "TrinketUITests", "Packages/Probe/Sources/Generated", "Packages/Probe/Tests"):
                (root / name).mkdir(parents=True)
            (root / "Packages/Probe/Sources/Generated/Probe.swift").write_text("let probe = NavigationView {}\n")
            (root / "TrinketUITests/Probe.swift").write_text("import XCTest\n")
            fixture = root / "Trinket/Probe.swift"
            fixture.write_text('// NavigationView\nlet text = "NavigationView"\n')
            command = [str(root / "Scripts/check-api-bans.sh")]
            passed = subprocess.run(command, cwd=root, capture_output=True, text=True)
            self.assertEqual(passed.returncode, 0, passed.stdout + passed.stderr)
            fixture.write_text('// NavigationView\nlet probe = NavigationView {}\n')
            failed = subprocess.run(command, cwd=root, capture_output=True, text=True,
                                    env={**os.environ, "GITHUB_ACTIONS": "true"})
            self.assertEqual(failed.returncode, 1, failed.stdout + failed.stderr)
            self.assertIn("Trinket/Probe.swift:2:", failed.stderr)
            self.assertIn("::error file=Trinket/Probe.swift,line=2,title=API Ban::", failed.stdout)
            fixture.write_text("struct Probe {}\n")
            generated_test = root / "Packages/Probe/Tests/Generated/Probe.swift"
            generated_test.parent.mkdir()
            generated_test.write_text("import XCTest\n")
            failed = subprocess.run(command, cwd=root, capture_output=True, text=True)
            self.assertEqual(failed.returncode, 1, failed.stdout + failed.stderr)
            self.assertIn("Packages/Probe/Tests/Generated/Probe.swift:1:", failed.stderr)

    def test_search_and_tokenizer_failures_do_not_pass(self) -> None:
        for status in (1, 2):
            result = subprocess.CompletedProcess([], status, "", "search error")
            with self.subTest(status=status), patch.object(self.policy.subprocess, "run", return_value=result):
                if status == 1:
                    self.assertEqual(self.policy.candidate_paths("api-bans", ["Trinket"], ROOT), [])
                else:
                    with self.assertRaisesRegex(RuntimeError, "Policy search failed"):
                        self.policy.candidate_paths("api-bans", ["Trinket"], ROOT)
        valid = self.policy.formatter_tokens("let value = 1\n", ROOT)
        version = subprocess.check_output([str(ROOT / ".tools/swiftformat"), "--version"], text=True).strip()
        exports = (
            (1, "", "tokenizer failed"),
            (0, "not json", ""),
            (0, json.dumps({"version": "0.0.0", "tokens": valid}), ""),
            (0, json.dumps({"version": version, "tokens": []}), ""),
        )
        for status, output, error in exports:
            with self.subTest(status=status, output=output), patch.object(
                self.policy.subprocess, "run", return_value=subprocess.CompletedProcess([], status, output, error)
            ), self.assertRaises(RuntimeError):
                self.policy.formatter_tokens("let value = 1\n", ROOT)

    def test_formatter_owns_rewrites_and_preserves_persisted_values(self) -> None:
        source = '''enum Temporary: String { case sample = "sample" }
// swiftformat:disable redundantRawValues - persisted identifiers
enum Persisted: String { case sample = "sample" }
// swiftformat:enable redundantRawValues
struct Probe {public nonisolated static func value( ) -> Int {return 1;}}
'''
        command = [str(ROOT / ".tools/swiftformat"), "stdin", "--config", str(ROOT / ".swiftformat"),
                   "--cache", "ignore", "--quiet"]
        unformatted = subprocess.run([*command, "--lint"], input=source, capture_output=True, text=True)
        self.assertNotEqual(unformatted.returncode, 0)
        formatted = subprocess.run(command, input=source, capture_output=True, text=True)
        self.assertEqual(formatted.returncode, 0, formatted.stderr)
        self.assertIn('case sample = "sample"', formatted.stdout)
        self.assertEqual(formatted.stdout.count('case sample = "sample"'), 1)
        linted = subprocess.run([*command, "--lint"], input=formatted.stdout, capture_output=True, text=True)
        self.assertEqual(linted.returncode, 0, linted.stderr)

    def test_complexity_and_file_size_count_code(self) -> None:
        mappings = "func probe(value: Int) -> Int {\n    switch value {\n" + "".join(
            f"    case {index}: {index}\n" for index in range(20)
        ) + "    default: 0\n    }\n}\n"
        branches = "func probe(value: Int) {\n    switch value {\n    default:\n" + "".join(
            f"        if value == {index} {{ print(value) }}\n" for index in range(16)
        ) + "    }\n}\n"
        cases = (
            (mappings, "cyclomatic_complexity", False),
            (branches, "cyclomatic_complexity", True),
            ("// rationale\n" * 601 + "struct Probe {}\n", "file_length", False),
            ("print(1)\n" * 601, "file_length", True),
        )
        for source, rule, should_fail in cases:
            with self.subTest(rule=rule, should_fail=should_fail):
                result = subprocess.run(
                    [str(ROOT / ".tools/swiftlint"), "lint", "--config", str(ROOT / ".swiftlint.yml"),
                     "--quiet", "--no-cache", "--use-stdin", "--only-rule", rule, "--reporter", "json"],
                    input=source, capture_output=True, text=True,
                )
                findings = [row for row in json.loads(result.stdout) if row["rule_id"] == rule]
                self.assertEqual(bool(findings), should_fail, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
