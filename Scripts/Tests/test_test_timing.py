#!/usr/bin/env python3

from __future__ import annotations

from datetime import datetime, timezone
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from script_test_support import load_script, run_captured, write_executable, write_json


SCRIPT = Path(__file__).parents[1] / "test-timing.py"


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
        return run_captured([sys.executable, str(SCRIPT), *args], env=environment)

    def test_timing_history_survives_successful_artifact_cleanup(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "TestResults"
            recorded = self.run_script(root, "record", "--mode", "unit", "--run", "retained", "--wall", "1", "--no-xcresult")
            self.assertEqual(recorded.returncode, 0, recorded.stderr)
            bundle = root / "passed.xcresult"
            bundle.mkdir()
            exports = root / "passed-xcresult-reports"
            exports.mkdir()
            (exports / "tests.json").write_text("{}")
            write_json(root / "passed-invocation.json", {"status": "passed", "exit_code": 0, "result_bundle": str(bundle)})
            maintenance = load_script("review_maintenance", "diagnostic_maintenance.py")
            maintenance.cleanup(root, False)
            self.assertFalse((root / "passed-invocation.json").exists())
            self.assertFalse(exports.exists())
            self.assertFalse(bundle.exists())
            report = self.run_script(root, "show")
            self.assertEqual(report.returncode, 0, report.stderr)
            self.assertIn("retained", report.stdout)

    def test_timing_queries_are_bounded_and_timeout_is_reported(self) -> None:
        xcresult_diagnostics = load_script("internal.diagnostics.xcresult_diagnostics", "internal/diagnostics/xcresult_diagnostics.py")
        timing = load_script("review_timing", "test-timing.py")
        with patch.object(xcresult_diagnostics.subprocess, "run", side_effect=subprocess.TimeoutExpired("xcresulttool", 120)) as query:
            with self.assertRaisesRegex(SystemExit, "timed out"):
                timing.parse_xcresult(Path("partial.xcresult"))
            self.assertEqual(query.call_args.kwargs["timeout"], 120)

    def test_exports_reuse_only_the_same_completed_bundle_and_recover_from_bad_cache(self) -> None:
        reports = load_script("internal.diagnostics.xcresult_diagnostics", "internal/diagnostics/xcresult_diagnostics.py")
        passed = {"testNodes": [{"nodeType": "Test Case", "nodeIdentifier": "Smoke/testJourney",
                                 "result": "Passed"}]}
        failed = {"testNodes": [{"nodeType": "Test Case", "nodeIdentifier": "Smoke/testJourney",
                                 "result": "Failed"}]}
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "invocation.xcresult"
            bundle.mkdir()
            info = bundle / "Info.plist"
            info.write_text("complete")
            cache = bundle.with_name(bundle.stem + "-xcresult-reports") / "tests.json"
            response = subprocess.CompletedProcess([], 0, json.dumps(passed), "")
            with patch.object(reports.subprocess, "run", return_value=response) as query:
                def read():
                    return reports.run_xcresulttool(bundle, ["get", "test-results", "tests"])
                self.assertEqual(read(), (passed, None))
                self.assertEqual(read(), (passed, None))
                self.assertEqual(query.call_count, 1)
                # A corrupted export and a replacement bundle must each be queried again.
                cache.write_text("not json")
                self.assertEqual(read(), (passed, None))
                saved = json.loads(cache.read_text())
                saved["identity"]["path"] = str(Path(directory) / "another.xcresult")
                write_json(cache, saved)
                self.assertEqual(read(), (passed, None))
                info.unlink()
                self.assertEqual(read(), (passed, None))
                info.write_text("replacement complete")
                query.return_value = subprocess.CompletedProcess([], 0, json.dumps(failed), "")
                self.assertEqual(read(), (failed, None))
                self.assertEqual(read(), (failed, None))
                self.assertEqual(query.call_count, 5)
                # Missing finalized evidence must not revive a cached passing or failing report.
                info.unlink()
                query.return_value = subprocess.CompletedProcess([], 1, "", "bundle incomplete")
                payload, error = read()
                self.assertIsNone(payload)
                self.assertIn("bundle incomplete", error)

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
                valid_entry | {"recorded_at": 10},
                valid_entry | {"xcresult": []},
                valid_entry | {"schema_version": True},
                valid_entry | {"summary": valid_entry["summary"] | {"passed": True}},
                valid_entry | {"tests": [{"id": "invalid", "name": "invalid", "seconds": False}]},
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
            self.assertIn("--last", malformed_last.stderr)
            self.assertNotIn("Traceback", malformed_last.stderr)

            unknown_option = self.run_script(results_dir, "report", "--bogus")
            self.assertNotEqual(unknown_option.returncode, 0)
            self.assertIn("--bogus", unknown_option.stderr)
            self.assertNotIn("Traceback", unknown_option.stderr)

    def test_invalid_retention_setting_does_not_write_history(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "timing-log.jsonl"
            log.write_text("existing history\n")
            result = self.run_script(root, "record", "--mode", "unit", "--run", "invalid-retention", "--wall", "1",
                                     "--no-xcresult", extra_environment={"TRINKET_KEEP_TIMING_HISTORY": "invalid"})
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("must be an integer", result.stderr)
            self.assertEqual(log.read_text(), "existing history\n")

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
            write_executable(
                tools / "xcrun",
                "#!/usr/bin/env bash\n"
                'printf "%s\\n" "$*" >> "$QUERY_LOG"\n'
                "if [[ \"$*\" == *\" summary \"* ]]; then\n"
                "  echo '{\"passedTests\":1,\"failedTests\":0,\"skippedTests\":0,\"result\":\"Passed\",\"startTime\":10,\"finishTime\":12}'\n"
                "else\n"
                "  echo '{\"testNodes\":[{\"nodeType\":\"Test Case\",\"nodeIdentifier\":\"ExampleTests/testOne\",\"name\":\"testOne\",\"durationInSeconds\":1,\"result\":\"Passed\"}]}'\n"
                "fi\n",
            )
            queries = results_dir / 'queries.log'
            environment = {"PATH": f"{tools}:{os.environ['PATH']}", "QUERY_LOG": str(queries)}

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

            # Filter validation runs in another process and shares timing's exact export.
            exported = run_captured([sys.executable, str(SCRIPT.parent / "xcresult-report.py"), str(bundle), "tests"], env={**os.environ, **environment}, expected=0)
            self.assertEqual(json.loads(exported.stdout)["testNodes"][0]["result"], "Passed")
            self.assertEqual(len(queries.read_text().splitlines()), 2)

            available = self.run_script(results_dir, "show", "--last", "1", "--mode", "ui")
            self.assertEqual(available.returncode, 0, available.stderr)
            self.assertIn(bundle.stem, available.stdout)
            self.assertIn("Passed | 1 passed, 0 failed, 0 skipped", available.stdout)
            self.assertIn("xcresult (available)", available.stdout)
            self.assertIn("ExampleTests/testOne", available.stdout)

            captured = {
                'schema_version': 1, 'action': 'test', 'result_bundle_complete': True,
                'result_bundle': str(bundle),
                'test_summary': {'passedTests': 1, 'failedTests': 0, 'skippedTests': 0,
                                 'result': 'Passed', 'startTime': 10, 'finishTime': 12},
            }
            manifest = results_dir / 'invocation.json'
            for summary, expected_queries in (
                (captured, 1),
                (captured | {'result_bundle': str(results_dir / 'another.xcresult')}, 2),
                (captured | {'test_summary': None}, 2),
            ):
                shutil.rmtree(bundle.with_name(bundle.stem + '-xcresult-reports'), ignore_errors=True)
                write_json(manifest, summary)
                queries.write_text('')
                reused = self.run_script(results_dir, 'record', '--mode', 'ui', '--run', 'captured',
                                         '--xcresult', str(bundle), '--manifest', str(manifest),
                                         extra_environment=environment)
                self.assertEqual(reused.returncode, 0, reused.stderr)
                self.assertEqual(len(queries.read_text().splitlines()), expected_queries)
                self.assertIn('1 passed, 0 failed, 0 skipped in 2.0s', reused.stdout)

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
                "recorded_at": datetime.now(timezone.utc).isoformat(),
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
                "recorded_at": datetime.now(timezone.utc).isoformat(),
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

    def test_class_report_aggregates_test_durations_per_invocation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            entries = []
            for run, durations in enumerate((
                {'ExampleTests/one': 10, 'ExampleTests/two': 1, 'OtherTests/one': 4},
                {'ExampleTests/one': 20, 'ExampleTests/two': 3},
            )):
                total = sum(durations.values())
                entries.append({
                    'mode': 'ui', 'run': str(run), 'wall_seconds': total,
                    'summary': {'passed': len(durations), 'failed': 0, 'skipped': 0,
                                'xcresult_seconds': total, 'measured_test_seconds': total},
                    'tests': [{'id': name, 'name': name, 'seconds': seconds} for name, seconds in durations.items()],
                })
            (root / 'timing-log.jsonl').write_text(''.join(json.dumps(entry) + '\n' for entry in entries))
            report = self.run_script(root, 'report', '--by-class', '--top', '0')
            self.assertEqual(report.returncode, 0, report.stderr)
            self.assertRegex(report.stdout, r'34\.0s\s+17\.0s\s+2\s+ExampleTests\n')
            self.assertRegex(report.stdout, r'4\.0s\s+4\.0s\s+1\s+OtherTests\n')


if __name__ == "__main__":
    unittest.main()
