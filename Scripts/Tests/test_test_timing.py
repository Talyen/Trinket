#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "test-timing.sh"


class TestTimingTests(unittest.TestCase):
    def run_script(self, results_dir: Path, *args: str) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["RESULTS_DIR"] = str(results_dir)
        return subprocess.run(
            [str(SCRIPT), *args],
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_malformed_history_is_skipped_and_numeric_inputs_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results_dir = Path(directory)
            log_path = results_dir / "timing-log.jsonl"
            valid_entry = {
                "schema_version": 1,
                "mode": "unit",
                "targets": [],
                "no_build": False,
                "wall_seconds": 2.0,
                "summary": {
                    "passed": 1,
                    "failed": 0,
                    "skipped": 0,
                    "xcresult_seconds": 1.0,
                    "measured_test_seconds": 1.0,
                },
                "tests": [
                    {"id": "ExampleTests/testOne", "name": "testOne", "seconds": 1.0}
                ],
            }
            malformed = [
                [],
                {"schema_version": 2, "mode": "unit", "summary": {}, "tests": []},
                {"schema_version": 1, "mode": "unit", "summary": {}, "tests": [{"seconds": "NaN"}]},
                {
                    "schema_version": 1,
                    "mode": "unit",
                    "summary": {},
                    "tests": [{"id": "bad", "name": "bad", "seconds": None}],
                },
                {"schema_version": 1, "mode": "unit", "wall_seconds": -1, "summary": {}, "tests": []},
            ]
            log_path.write_text(
                "\n".join([*(json.dumps(entry) for entry in malformed), json.dumps(valid_entry), "not json"])
                + "\n",
                encoding="utf-8",
            )

            report = self.run_script(results_dir, "report")
            self.assertEqual(report.returncode, 0, report.stderr)
            self.assertIn("Entries: 1 total", report.stdout)
            self.assertIn("ExampleTests/testOne", report.stdout)
            self.assertNotIn("Traceback", report.stderr)

            for value in ("NaN", "-1"):
                budget = self.run_script(
                    results_dir,
                    "assert-budget",
                    "--mode",
                    "unit",
                    "--max-wall",
                    value,
                )
                self.assertNotEqual(budget.returncode, 0)
                self.assertIn("finite non-negative number", budget.stderr)
                self.assertNotIn("Traceback", budget.stderr)

            record = self.run_script(
                results_dir,
                "record",
                "--mode",
                "unit",
                "--wall",
                "NaN",
                "--xcresult",
                str(results_dir / "missing.xcresult"),
            )
            self.assertNotEqual(record.returncode, 0)
            self.assertIn("finite non-negative number", record.stderr)
            self.assertNotIn("Traceback", record.stderr)

            malformed_last = self.run_script(results_dir, "report", "--last", "NaN")
            self.assertNotEqual(malformed_last.returncode, 0)
            self.assertIn("--last must be a positive integer", malformed_last.stderr)
            self.assertNotIn("Traceback", malformed_last.stderr)

            unknown_option = self.run_script(results_dir, "report", "--bogus")
            self.assertNotEqual(unknown_option.returncode, 0)
            self.assertIn("unknown option: --bogus", unknown_option.stderr)
            self.assertNotIn("Traceback", unknown_option.stderr)

    def test_wall_only_record_without_xcresult(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results_dir = Path(directory)
            record = self.run_script(
                results_dir,
                "record",
                "--mode",
                "unit",
                "--wall",
                "12.5",
                "--no-xcresult",
            )
            self.assertEqual(record.returncode, 0, record.stderr)
            self.assertNotIn("Traceback", record.stderr)

            report = self.run_script(results_dir, "report", "--mode", "unit")
            self.assertEqual(report.returncode, 0, report.stderr)
            self.assertIn("Entries: 1 total", report.stdout)
            self.assertIn("12.5s", report.stdout)

            budget = self.run_script(
                results_dir,
                "assert-budget",
                "--mode",
                "unit",
                "--max-wall",
                "20",
            )
            self.assertEqual(budget.returncode, 0, budget.stderr)
            self.assertIn("wall", budget.stdout)

            mutually_exclusive = self.run_script(
                results_dir,
                "record",
                "--mode",
                "unit",
                "--wall",
                "1",
                "--no-xcresult",
                "--xcresult",
                str(results_dir / "missing.xcresult"),
            )
            self.assertNotEqual(mutually_exclusive.returncode, 0)
            self.assertIn("exactly one of --xcresult or --no-xcresult", mutually_exclusive.stderr)
            self.assertNotIn("Traceback", mutually_exclusive.stderr)


if __name__ == "__main__":
    unittest.main()
