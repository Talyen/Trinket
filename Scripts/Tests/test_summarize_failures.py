#!/usr/bin/env python3
"""Focused tests for the Xcode failure reporter.

These tests intentionally exercise the reporter without requiring Xcode or a
simulator.  Fixture JSON represents the public xcresulttool report APIs and
the tool calls are patched at the process boundary.
"""

from __future__ import annotations

import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
CLI_SCRIPT = ROOT / "Scripts" / "summarize-failures.py"
FIXTURES = ROOT / "Scripts" / "Tests" / "Fixtures"
sys.path.insert(0, str(ROOT / "Scripts"))
import failure_diagnostics as REPORTER  # noqa: E402


def fixture(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


def namespace(bundle: Path, log: Path | None, exit_code: int, prefix: Path) -> SimpleNamespace:
    return SimpleNamespace(
        result_bundle=str(bundle),
        log=str(log) if log else "",
        exit_code=exit_code,
        label="Fixture",
        output_prefix=str(prefix),
        defer_terminal_output=True,
    )


class ReporterTests(unittest.TestCase):
    def test_structured_sources_are_authoritative_and_deduplicated(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / "Fixture.xcresult"
            bundle.mkdir()
            log = root / "xcodebuild.log"
            log.write_text("ignored: structured reports contain the failure\n", encoding="utf-8")
            prefix = root / "report"
            responses = {
                ("get", "build-results"): fixture("build-results.json"),
                ("get", "test-results", "summary"): fixture("test-summary.json"),
                ("get", "test-results", "tests"): fixture("tests.json"),
                ("get", "test-results", "test-details"): fixture("test-details.json"),
            }

            def query(_bundle: Path, arguments: list[str]):
                key = tuple(arguments[:3]) if "test-details" in arguments else tuple(arguments)
                return responses[key], None

            def export(_bundle: Path, output: Path):
                output.mkdir(parents=True, exist_ok=True)
                (output / "manifest.json").write_text("[]\n", encoding="utf-8")
                (output / "failure.txt").write_text("failure attachment\n", encoding="utf-8")
                return True, None

            with patch.object(REPORTER.xcresult, "run_xcresulttool", side_effect=query), patch.object(REPORTER.xcresult, "export_failure_attachments", side_effect=export):
                report = REPORTER.build_report(namespace(bundle, log, 1, prefix))

            self.assertEqual(report.classification, "test-failure")
            self.assertEqual(len(report.issues), 1)
            self.assertEqual(report.sources.test_details, 1)
            self.assertTrue(report.sources.attachments)
            self.assertEqual(report.issues[0].file, "BattleTests.swift")
            self.assertEqual(report.issues[0].line, 42)
            self.assertEqual(len(report.attachments), 1)
            self.assertIn("failure.txt", REPORTER.render_markdown(report))
            self.assertNotIn("raw_log_path", report.to_dict())

    def test_distinct_assertions_in_one_test_remain_distinct(self) -> None:
        accumulator = REPORTER.IssueAccumulator()
        for observation in REPORTER.parse_summary(fixture("test-summary-multiple.json")):
            accumulator.add(observation)
        observations, failed_ids = REPORTER.parse_test_nodes(fixture("tests-multiple.json"))
        for observation in observations:
            accumulator.add(observation)

        issues = accumulator.finalize()

        self.assertEqual(
            failed_ids,
            ["test://com.apple.xcode/Trinket/TrinketTests/BattleTests/multipleFailures()"],
        )
        self.assertEqual(len(issues), 2)
        self.assertEqual({issue.line for issue in issues}, {42, 57})
        self.assertEqual(
            {issue.message for issue in issues},
            {
                "Expectation failed: score == 2",
                "Expectation failed: health == 10",
            },
        )

    def test_attachments_are_assigned_by_test_identifier(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "manifest.json").write_text(
                json.dumps(fixture("attachments-multiple.json")),
                encoding="utf-8",
            )
            for name in ("first.png", "second.png", "runner.txt"):
                (root / name).write_text(name, encoding="utf-8")
            issues = [
                REPORTER.DiagnosticIssue.from_observation(
                    REPORTER.IssueObservation(
                        "test-failure",
                        "firstFailure()",
                        "first failed",
                        test="BattleTests/firstFailure()",
                    )
                ),
                REPORTER.DiagnosticIssue.from_observation(
                    REPORTER.IssueObservation(
                        "test-failure",
                        "secondFailure()",
                        "second failed",
                        test="BattleTests/secondFailure()",
                    )
                ),
            ]

            unmatched = REPORTER.assign_attachments(
                issues,
                root,
                REPORTER.xcresult.read_exported_attachments(root),
            )

            self.assertEqual([Path(path).name for path in issues[0].attachments], ["first.png"])
            self.assertEqual([Path(path).name for path in issues[1].attachments], ["second.png"])
            self.assertEqual([Path(path).name for path in unmatched], ["runner.txt"])

    def test_build_failure_classification_and_location_are_structured(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / "Build.xcresult"
            bundle.mkdir()
            log = root / "build.log"
            log.write_text("not used\n", encoding="utf-8")
            prefix = root / "report"
            responses = {
                ("get", "build-results"): fixture("build-failure.json"),
                ("get", "test-results", "summary"): {"result": "Passed", "testFailures": []},
                ("get", "test-results", "tests"): {"testNodes": []},
            }

            def query(_bundle: Path, arguments: list[str]):
                return responses[tuple(arguments)], None

            with patch.object(REPORTER.xcresult, "run_xcresulttool", side_effect=query), patch.object(REPORTER.xcresult, "export_failure_attachments", return_value=(True, None)):
                report = REPORTER.build_report(namespace(bundle, log, 65, prefix))

            self.assertEqual(report.classification, "build-failure")
            self.assertEqual(report.issues[0].kind, "build-failure")
            self.assertEqual(report.issues[0].message, "Cannot find type 'MissingType' in scope")
            self.assertNotIn("raw_log_path", report.to_dict())

    def test_log_fallback_classifies_simulator_without_exposing_raw_path(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / "missing.xcresult"
            log = root / "xcodebuild.log"
            log.write_text("xcodebuild: error: Unable to boot the Simulator device\n", encoding="utf-8")
            prefix = root / "report"
            report = REPORTER.build_report(namespace(bundle, log, 70, prefix))

            self.assertEqual(report.classification, "simulator-infrastructure")
            self.assertEqual(len(report.issues), 1)
            self.assertNotIn("raw_log_path", report.to_dict())

    def test_log_fallback_scans_past_two_megabytes_and_classifies_late_linker_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            log = root / "long-build.log"
            with log.open("w", encoding="utf-8") as stream:
                stream.write("ordinary build output\n" * 140_000)
                stream.write("clang: error: linker command failed with exit code 1\n")
            report = REPORTER.build_report(namespace(root / "missing.xcresult", log, 1, root / "report"))

            self.assertEqual(report.classification, "build-failure")
            self.assertTrue(any("linker command failed" in issue.message for issue in report.issues))
            self.assertNotIn("raw_log_path", report.to_dict())

    def test_log_fallback_covers_crash_timeout_configuration_and_tooling(self) -> None:
        cases = (
            ("Test process crashed: signal SIGABRT", "test-failure"),
            ("Test execution timed out after 60 seconds", "test-failure"),
            (
                "Failed to launch app via Xcode: Timed out while launching application via Xcode.",
                "simulator-infrastructure",
            ),
            (
                "Failed to get background assertion for target app with pid 18060",
                "simulator-infrastructure",
            ),
            ("xcodebuild: error: Scheme 'Trinket' not found", "configuration"),
            ("xcode-select: error: toolchain is not configured", "tooling"),
        )
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for index, (message, expected) in enumerate(cases):
                log = root / f"case-{index}.log"
                log.write_text(message + "\n", encoding="utf-8")
                report = REPORTER.build_report(namespace(root / f"missing-{index}.xcresult", log, 1, root / f"report-{index}"))
                self.assertEqual(report.classification, expected, message)
                self.assertEqual(report.issues[0].kind, expected, message)

    def test_github_annotations_and_step_summary_are_emitted(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / "missing.xcresult"
            log = root / "build.log"
            log.write_text("Sources/App.swift:17: error: linker command failed\n", encoding="utf-8")
            prefix = root / "diagnostics"
            step_summary = root / "step-summary.md"
            stdout = io.StringIO()
            stderr = io.StringIO()
            with patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "GITHUB_STEP_SUMMARY": str(step_summary)}, clear=False):
                with redirect_stdout(stdout), redirect_stderr(stderr):
                    self.assertEqual(
                        REPORTER.main(
                            [
                                "--result-bundle",
                                str(bundle),
                                "--log",
                                str(log),
                                "--exit-code",
                                "1",
                                "--label",
                                "github",
                                "--output-prefix",
                                str(prefix),
                            ]
                        ),
                        0,
                    )
            self.assertIn("::error", stdout.getvalue())
            self.assertIn("Sources/App.swift", stdout.getvalue())
            self.assertIn("Failure diagnostics: github", step_summary.read_text(encoding="utf-8"))
            self.assertIn("::error", (root / "diagnostics.annotations").read_text(encoding="utf-8"))

    def test_executable_cli_invokes_main_guard_and_writes_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            log = root / "opaque.log"
            log.write_text("opaque runner output\n", encoding="utf-8")
            prefix = root / "cli-report"
            completed = subprocess.run(
                [
                    sys.executable,
                    str(CLI_SCRIPT),
                    "--result-bundle",
                    str(root / "missing.xcresult"),
                    "--log",
                    str(log),
                    "--exit-code",
                    "1",
                    "--label",
                    "cli",
                    "--output-prefix",
                    str(prefix),
                    "--defer-terminal-output",
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertEqual(completed.stdout, "")
            self.assertEqual(completed.stderr, "")
            self.assertTrue((root / "cli-report.json").exists())
            self.assertTrue((root / "cli-report.md").exists())
            self.assertTrue((root / "cli-report.annotations").exists())

    def test_unknown_log_fallback_is_bounded_and_exposes_raw_path_only_for_unknown(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            log = root / "xcodebuild.log"
            log.write_text("opaque runner output\n", encoding="utf-8")
            report = REPORTER.build_report(namespace(root / "missing.xcresult", log, 1, root / "report"))
            self.assertEqual(report.classification, "unknown")
            self.assertEqual(report.issues[0].kind, "unknown")
            self.assertEqual(report.raw_log_path, str(log.resolve()))

    def test_terminal_and_markdown_are_bounded_while_json_is_complete(self) -> None:
        issues = [REPORTER.DiagnosticIssue("build-failure", f"Issue {index}", f"error {index}") for index in range(35)]
        report = REPORTER.DiagnosticReport(
            label="Many", result_bundle="", log="", exit_code=1,
            classification="build-failure", issues=issues,
            sources=REPORTER.SourceStatus(), generated_at="fixture",
        )
        terminal = REPORTER.render_terminal(report)
        markdown = REPORTER.render_markdown(report).splitlines()
        self.assertEqual(len(report.issues), 35)
        self.assertLessEqual(len(terminal), REPORTER.MAX_LINES)
        self.assertLessEqual(len(markdown), REPORTER.MAX_LINES)
        self.assertIn("additional issues", "\n".join(terminal))
        self.assertIn("additional issues", "\n".join(markdown))

    def test_main_writes_complete_artifacts_and_reports_execution_errors(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / "missing.xcresult"
            log = root / "xcodebuild.log"
            log.write_text("opaque output\n", encoding="utf-8")
            prefix = root / "diagnostics"
            stdout = io.StringIO()
            stderr = io.StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr):
                result = REPORTER.main(
                    [
                        "--result-bundle",
                        str(bundle),
                        "--log",
                        str(log),
                        "--exit-code",
                        "1",
                        "--label",
                        "unit",
                        "--output-prefix",
                        str(prefix),
                        "--defer-terminal-output",
                    ]
                )
            self.assertEqual(result, 0)
            self.assertEqual(stdout.getvalue(), "")
            self.assertEqual(stderr.getvalue(), "")
            self.assertTrue((root / "diagnostics.json").exists())
            self.assertTrue((root / "diagnostics.md").exists())
            self.assertTrue((root / "diagnostics.annotations").exists())
            normal_stdout = io.StringIO()
            normal_stderr = io.StringIO()
            with redirect_stdout(normal_stdout), redirect_stderr(normal_stderr):
                self.assertEqual(
                    REPORTER.main(
                        [
                            "--result-bundle",
                            str(bundle),
                            "--log",
                            str(log),
                            "--exit-code",
                            "1",
                            "--label",
                            "unit",
                            "--output-prefix",
                            str(root / "normal"),
                        ]
                    ),
                    0,
                )
            self.assertIn("failure diagnostics", normal_stdout.getvalue())
            self.assertIn("Report JSON", normal_stderr.getvalue())

            with patch.object(REPORTER, "build_report", side_effect=RuntimeError("fixture failure")):
                error = io.StringIO()
                with redirect_stderr(error):
                    self.assertEqual(REPORTER.main(["--result-bundle", str(bundle)]), 2)
                self.assertIn("reporter execution failed", error.getvalue())

    def test_report_json_remains_compatible_with_ci_aggregator(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            report = REPORTER.DiagnosticReport(
                label="compatibility",
                result_bundle=str(root / "missing.xcresult"),
                log="",
                exit_code=1,
                classification="test-failure",
                issues=[REPORTER.DiagnosticIssue("test-failure", "Failure", "Expectation failed")],
                sources=REPORTER.SourceStatus(test_summary=True),
                generated_at="2026-08-08T00:00:00Z",
                attachments=[str(root / "runner.txt")],
            )
            REPORTER.write_report(report, str(root / "fixture-diagnostics"))
            aggregate_path = root / "ci-diagnostics.json"

            completed = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "Scripts" / "ci-diagnostics.py"),
                    str(root),
                    str(aggregate_path),
                ],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(completed.returncode, 0, completed.stderr)
            aggregate = json.loads(aggregate_path.read_text(encoding="utf-8"))
            self.assertEqual(aggregate["category"], "test-failure")
            self.assertEqual(aggregate["issues"][0]["message"], "Expectation failed")

    def test_ci_aggregator_distinguishes_watchdog_proof_from_partial_xcresult(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / "partial.xcresult"
            (bundle / "Data").mkdir(parents=True)
            manifest_path = root / "watchdog-invocation.json"
            manifest = {
                "schema_version": 1,
                "label": "smoke",
                "exit_code": 0,
                "status": "passed",
                "result_bundle": str(bundle),
                "diagnostics_json": "",
                "completion_source": "watchdog-log-inference",
                "test_execution_proven": True,
                "result_bundle_complete": False,
            }
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            aggregate_path = root / "ci-diagnostics.json"

            accepted = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "Scripts" / "ci-diagnostics.py"),
                    str(root),
                    str(aggregate_path),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(accepted.returncode, 0, accepted.stderr)
            aggregate = json.loads(aggregate_path.read_text(encoding="utf-8"))
            self.assertEqual(aggregate["category"], "passed")
            self.assertEqual(aggregate["incomplete_result_invocations"], 1)
            self.assertIn("watchdog log proof", aggregate["detail"])

            manifest["completion_source"] = "process-exit"
            manifest["test_execution_proven"] = False
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            rejected = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "Scripts" / "ci-diagnostics.py"),
                    str(root),
                    str(aggregate_path),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(rejected.returncode, 0, rejected.stderr)
            aggregate = json.loads(aggregate_path.read_text(encoding="utf-8"))
            self.assertEqual(aggregate["category"], "unknown")
            self.assertEqual(aggregate["failed_invocations"], 1)


if __name__ == "__main__":
    unittest.main()
