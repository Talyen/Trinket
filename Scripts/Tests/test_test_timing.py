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
    def run_script(
        self,
        results_dir: Path,
        *args: str,
        extra_environment: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["RESULTS_DIR"] = str(results_dir)
        environment.update(extra_environment or {})
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

            record = self.run_script(
                results_dir,
                "record",
                "--mode",
                "unit",
                "--run",
                "unit-invalid",
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
                "--run",
                "unit-wall-only",
                "--wall",
                "12.5",
                "--no-xcresult",
            )
            self.assertEqual(record.returncode, 0, record.stderr)
            self.assertIn("wall-only timing 12.5s (run unit-wall-only)", record.stdout)
            self.assertNotIn("Traceback", record.stderr)

            report = self.run_script(results_dir, "report", "--mode", "unit")
            self.assertEqual(report.returncode, 0, report.stderr)
            self.assertIn("Entries: 1 total", report.stdout)
            self.assertIn("12.5s", report.stdout)

            mutually_exclusive = self.run_script(
                results_dir,
                "record",
                "--mode",
                "unit",
                "--run",
                "unit-mutually-exclusive",
                "--wall",
                "1",
                "--no-xcresult",
                "--xcresult",
                str(results_dir / "missing.xcresult"),
            )
            self.assertNotEqual(mutually_exclusive.returncode, 0)
            self.assertIn("exactly one of --xcresult or --no-xcresult", mutually_exclusive.stderr)
            self.assertNotIn("Traceback", mutually_exclusive.stderr)

    def test_incomplete_xcresult_fails_without_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results_dir = Path(directory)
            partial = results_dir / "partial.xcresult"
            (partial / "Data").mkdir(parents=True)

            record = self.run_script(
                results_dir,
                "record",
                "--mode",
                "smoke",
                "--run",
                "smoke-incomplete",
                "--wall",
                "5",
                "--xcresult",
                str(partial),
            )
            self.assertNotEqual(record.returncode, 0)
            self.assertIn("xcresult is incomplete", record.stderr)
            self.assertNotIn("Traceback", record.stderr)

    def test_record_summary_and_show_include_run_and_bundle_state(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results_dir = Path(directory)
            bundle = results_dir / "ui-20260824T144749Z-59220-12206.xcresult"
            bundle.mkdir(parents=True)
            (bundle / "Info.plist").write_text("complete\n", encoding="utf-8")
            tools = results_dir / "tools"
            tools.mkdir()
            xcrun = tools / "xcrun"
            xcrun.write_text(
                "#!/usr/bin/env bash\n"
                "if [[ \"$*\" == *\" summary \"* ]]; then\n"
                "  echo '{\"passedTests\":1,\"failedTests\":0,\"skippedTests\":0,\"result\":\"Passed\",\"startTime\":10,\"finishTime\":12}'\n"
                "else\n"
                "  echo '{\"testNodes\":[{\"nodeType\":\"Test Case\",\"nodeIdentifier\":\"ExampleTests/testOne\",\"name\":\"testOne\",\"durationInSeconds\":1,\"result\":\"Passed\"}]}'\n"
                "fi\n",
                encoding="utf-8",
            )
            xcrun.chmod(0o755)
            environment = {"PATH": f"{tools}:{os.environ['PATH']}"}

            record = self.run_script(
                results_dir,
                "record",
                "--mode",
                "ui",
                "--run",
                bundle.stem,
                "--wall",
                "3",
                "--xcresult",
                str(bundle),
                "ExampleTests/testOne",
                extra_environment=environment,
            )
            self.assertEqual(record.returncode, 0, record.stderr)
            self.assertIn("1 passed, 0 failed, 0 skipped", record.stdout)
            self.assertIn(f"(run {bundle.stem})", record.stdout)

            available = self.run_script(results_dir, "show", "--last", "1", "--mode", "ui")
            self.assertEqual(available.returncode, 0, available.stderr)
            self.assertIn(bundle.stem, available.stdout)
            self.assertIn("Passed | 1 passed, 0 failed, 0 skipped", available.stdout)
            self.assertIn("xcresult (available)", available.stdout)
            self.assertIn("ExampleTests/testOne", available.stdout)

            for child in bundle.iterdir():
                child.unlink()
            bundle.rmdir()
            pruned = self.run_script(results_dir, "show", "--last", "1")
            self.assertIn("xcresult (pruned)", pruned.stdout)

    def test_show_supports_legacy_and_wall_only_entries(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results_dir = Path(directory)
            log_path = results_dir / "timing-log.jsonl"
            base = {
                "schema_version": 1,
                "recorded_at": "2026-08-24T14:47:39+00:00",
                "mode": "ui",
                "targets": ["ExampleTests/testOne"],
                "no_build": False,
                "wall_seconds": 5,
                "summary": {
                    "passed": 0,
                    "failed": 0,
                    "skipped": 0,
                    "result": "wall-only",
                    "xcresult_seconds": None,
                    "measured_test_seconds": 0,
                },
                "tests": [],
            }
            legacy = {
                **base,
                "recorded_at": "2026-08-24T14:46:00+00:00",
                "xcresult": "/tmp/ui-legacy-token.xcresult",
            }
            wall_only = {**base, "run": "ui-current-token", "xcresult": ""}
            log_path.write_text(
                json.dumps(legacy) + "\n" + json.dumps(wall_only) + "\n",
                encoding="utf-8",
            )

            show = self.run_script(results_dir, "show", "--last", "2", "--mode", "ui")
            self.assertEqual(show.returncode, 0, show.stderr)
            self.assertIn("ui-legacy-token", show.stdout)
            self.assertIn("ui-current-token", show.stdout)
            self.assertIn("xcresult (not recorded/incomplete)", show.stdout)


if __name__ == "__main__":
    unittest.main()
