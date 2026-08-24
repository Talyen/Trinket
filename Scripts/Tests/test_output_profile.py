#!/usr/bin/env python3
"""Focused tests for metadata-only routed command output profiling."""

from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts" / "output-profile.py"
SPEC = importlib.util.spec_from_file_location("output_profile", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
PROFILE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = PROFILE
SPEC.loader.exec_module(PROFILE)


class OutputProfileTests(unittest.TestCase):
    def run_cli(
        self,
        directory: Path,
        *arguments: str,
        environment: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        child_environment = os.environ.copy()
        child_environment["TRINKET_OUTPUT_PROFILE_DIR"] = str(directory)
        child_environment["TRINKET_OUTPUT_PROFILE_ENV"] = "local"
        child_environment.pop("TRINKET_OUTPUT_PROFILE", None)
        child_environment.update(environment or {})
        return subprocess.run(
            [sys.executable, str(SCRIPT), *arguments],
            cwd=ROOT,
            env=child_environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def profile_files(self, directory: Path) -> list[Path]:
        return sorted(directory.glob("*.jsonl"))

    def read_records(self, directory: Path) -> list[dict[str, object]]:
        return [json.loads(path.read_text(encoding="utf-8")) for path in self.profile_files(directory)]

    def test_run_streams_both_channels_and_records_counts_without_command(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            command = [
                sys.executable,
                "-c",
                "import sys; print('out'); print('err', file=sys.stderr)",
            ]
            result = self.run_cli(directory, "run", "--label", "scripts/check", "--policy", "live", "--", *command)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "out\n")
            self.assertEqual(result.stderr, "err\n")
            records = self.read_records(directory)
            self.assertEqual(len(records), 1)
            record = records[0]
            self.assertEqual(record["label"], "scripts/check")
            self.assertEqual(record["environment"], "local")
            self.assertEqual(record["status"], "passed")
            self.assertEqual(record["stdout_lines"], 1)
            self.assertEqual(record["stdout_bytes"], 4)
            self.assertEqual(record["stderr_lines"], 1)
            self.assertEqual(record["stderr_bytes"], 4)
            self.assertEqual(record["total_lines"], 2)
            self.assertEqual(record["total_bytes"], 8)
            self.assertEqual(record["output_policy"], "live")
            encoded = json.dumps(record)
            self.assertNotIn("import sys", encoded)
            self.assertIn("scripts/check", encoded)
            self.assertNotIn("print('out')", encoded)

    def test_failed_status_preserves_exit_code_and_unterminated_lines(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            result = self.run_cli(
                directory,
                "run",
                "--label",
                "failing-check",
                "--",
                sys.executable,
                "-c",
                "import sys; sys.stdout.write('partial'); sys.exit(7)",
            )

            self.assertEqual(result.returncode, 7)
            self.assertEqual(result.stdout, "partial")
            record = self.read_records(directory)[0]
            self.assertEqual(record["status"], "failed")
            self.assertEqual(record["exit_code"], 7)
            self.assertEqual(record["stdout_lines"], 1)
            self.assertEqual(record["stdout_bytes"], 7)

    def test_report_since_filters_latest_groups_but_preserves_history(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)

            def add(label: str, recorded_at: str, lines: int) -> None:
                metrics = {
                    "stdout_lines": lines,
                    "stdout_bytes": lines,
                    "stderr_lines": 0,
                    "stderr_bytes": 0,
                    "total_lines": lines,
                    "total_bytes": lines,
                }
                entry = PROFILE._record_entry(
                    label=label,
                    environment="local",
                    status="passed",
                    exit_code=0,
                    wall_seconds=0.1,
                    metrics=metrics,
                    output_policy="live",
                )
                entry["recorded_at"] = recorded_at
                PROFILE.write_record(entry, directory)

            for index in range(5):
                add("trend-check", f"2026-08-24T00:00:0{index}+00:00", 10)
            add("trend-check", "2026-08-24T00:00:05+00:00", 31)
            add("old-check", "2026-08-23T23:59:59+00:00", 61)

            result = self.run_cli(
                directory,
                "report",
                "--local",
                "--actionable",
                "--since",
                "2026-08-24T00:00:05Z",
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("trend-check [passed]", result.stdout)
            self.assertNotIn("old-check", result.stdout)

            malformed = self.run_cli(directory, "report", "--local", "--since", "not-a-timestamp")
            self.assertNotEqual(malformed.returncode, 0)
            self.assertIn("valid ISO-8601 timestamp", malformed.stderr)

    def test_profile_disabled_is_passthrough_and_writes_no_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            result = self.run_cli(
                directory,
                "run",
                "--label",
                "disabled",
                "--",
                sys.executable,
                "-c",
                "import sys; print('passthrough'); sys.exit(9)",
                environment={"TRINKET_OUTPUT_PROFILE": "0"},
            )
            self.assertEqual(result.returncode, 9)
            self.assertEqual(result.stdout, "passthrough\n")
            self.assertEqual(self.profile_files(directory), [])

    def test_ci_summary_is_compact_and_metadata_does_not_contain_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            summary = directory / "summary.md"
            result = self.run_cli(
                directory,
                "run",
                "--environment",
                "ci",
                "--label",
                "ci-gate",
                "--",
                sys.executable,
                "-c",
                "print('secret child output')",
                environment={"GITHUB_STEP_SUMMARY": str(summary)},
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("ci-gate", summary.read_text(encoding="utf-8"))
            self.assertNotIn("secret child output", summary.read_text(encoding="utf-8"))
            self.assertEqual(len(self.read_records(directory)), 1)
            self.assertNotIn("secret child output", self.profile_files(directory)[0].read_text(encoding="utf-8"))

    def test_retains_newest_fifty_sessions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            metric = {
                "stdout_lines": 0,
                "stdout_bytes": 0,
                "stderr_lines": 0,
                "stderr_bytes": 0,
                "total_lines": 0,
                "total_bytes": 0,
            }
            for index in range(55):
                PROFILE.write_record(
                    PROFILE._record_entry(
                        label=f"check-{index}",
                        environment="local",
                        status="passed",
                        exit_code=0,
                        wall_seconds=0.001,
                        metrics=metric,
                        output_policy="live",
                    ),
                    directory,
                    retain_local=True,
                )
            self.assertEqual(len(self.profile_files(directory)), 50)

    def test_malformed_rows_are_ignored_and_local_report_filters_ci(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            valid = PROFILE._record_entry(
                label="valid",
                environment="local",
                status="passed",
                exit_code=0,
                wall_seconds=0.1,
                metrics={
                    "stdout_lines": 1,
                    "stdout_bytes": 2,
                    "stderr_lines": 0,
                    "stderr_bytes": 0,
                    "total_lines": 1,
                    "total_bytes": 2,
                },
                output_policy="live",
            )
            path = directory / "records.jsonl"
            path.write_text(
                json.dumps(valid) + "\nnot json\n" + json.dumps({"schema_version": 99}) + "\n",
                encoding="utf-8",
            )
            ci = dict(valid)
            ci["environment"] = "ci"
            (directory / "ci.jsonl").write_text(json.dumps(ci) + "\n", encoding="utf-8")
            result = self.run_cli(directory, "report", "--local")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("1 valid samples", result.stdout)
            self.assertIn("valid", result.stdout)

    def test_actionable_report_covers_budget_trend_and_recurring_cases(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)

            def add(label: str, lines: int, bytes_count: int, index: int) -> None:
                metrics = {
                    "stdout_lines": lines,
                    "stdout_bytes": bytes_count,
                    "stderr_lines": 0,
                    "stderr_bytes": 0,
                    "total_lines": lines,
                    "total_bytes": bytes_count,
                }
                entry = PROFILE._record_entry(
                    label=label,
                    environment="local",
                    status="passed",
                    exit_code=0,
                    wall_seconds=0.1,
                    metrics=metrics,
                    output_policy="live",
                )
                entry["recorded_at"] = f"2026-08-24T00:00:{index:02d}+00:00"
                PROFILE.write_record(entry, directory)

            for index in range(5):
                add("trend", 10, 100, index)
            add("trend", 31, 4_300, 5)
            for index in range(5):
                add("recurring", 61 if index in {2, 3} else 1, 100, 10 + index)
            add("recurring", 61, 100, 15)
            add("budget", 61, 100, 20)

            result = self.run_cli(directory, "report", "--local", "--actionable")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Actionable output hotspots:", result.stdout)
            self.assertIn("trend", result.stdout)
            self.assertIn("recurring", result.stdout)
            self.assertIn("budget", result.stdout)
            self.assertLessEqual(sum(line.startswith("- ") for line in result.stdout.splitlines()), 3)

    def test_pass_and_fail_history_are_compared_separately(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            for index in range(5):
                result = self.run_cli(
                    directory,
                    "run",
                    "--label",
                    "same-label",
                    "--",
                    sys.executable,
                    "-c",
                    "print('x')",
                )
                self.assertEqual(result.returncode, 0)
            result = self.run_cli(
                directory,
                "run",
                "--label",
                "same-label",
                "--",
                sys.executable,
                "-c",
                "import sys; print('x' * 15000); sys.exit(1)",
            )
            self.assertEqual(result.returncode, 1)
            report = self.run_cli(directory, "report", "--local", "--actionable")
            self.assertEqual(report.returncode, 0, report.stderr)
            self.assertIn("same-label [failed]", report.stdout)


if __name__ == "__main__":
    unittest.main()
