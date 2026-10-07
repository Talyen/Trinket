#!/usr/bin/env python3

from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/Tests/performance_test_support.py',
    'Scripts/aggregate-performance-results.py',
    'Scripts/collect-performance-results.py',
    'Scripts/compare-performance.py',
    'Scripts/internal/performance/performance_model.py',
    'Scripts/performance-scenarios.py',
    'Scripts/performance.sh',
    'Scripts/performance_environment.py',
)


import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from performance_test_support import report
from script_test_support import ROOT, load_script


SCRIPT = ROOT / "Scripts/aggregate-performance-results.py"
aggregate_performance = load_script("aggregate_performance", "aggregate-performance-results.py")


class AggregatePerformanceTests(unittest.TestCase):
    def test_collection_retains_invalid_iterations_for_validation(self) -> None:
        for iteration in (None, "broken"):
            with self.subTest(iteration=iteration), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                logs = root / "TestResults"
                logs.mkdir()
                invalid = {"scenario": "navigation", "schemaVersion": 5, "iteration": iteration}
                (logs / "run.log").write_text("TRINKET_PERFORMANCE_REPORT " + json.dumps(invalid) + "\n")
                output = root / "reports.json"
                result = subprocess.run(
                    [sys.executable, str(SCRIPT.with_name("collect-performance-results.py")), str(logs), str(output)],
                    capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                records = json.loads(output.read_text())["reports"]
                self.assertEqual(records[0]["iteration"], iteration)
                status, summary = self.run_aggregate(records)
                self.assertEqual(status, 1)
                self.assertIn("iteration must be a positive integer", summary)

    def test_collection_retains_measurements_when_environment_is_damaged(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            logs = root / "TestResults"
            logs.mkdir()
            measurement = report()
            (logs / "run.log").write_text("TRINKET_PERFORMANCE_REPORT " + json.dumps(measurement) + "\n")
            output = root / "reports.json"
            for metadata in ("broken JSON", "[]"):
                with self.subTest(metadata=metadata):
                    (root / "environment.json").write_text(metadata)
                    result = subprocess.run(
                        [sys.executable, str(SCRIPT.with_name("collect-performance-results.py")), str(logs), str(output)],
                        capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    record = json.loads(output.read_text())["reports"][0]
                    self.assertEqual(record["averageFPS"], measurement["averageFPS"])
                    self.assertEqual(record["sourceLog"], "run.log")
                    self.assertIn("environment.json", result.stdout)

    def run_aggregate(
        self,
        reports: list[dict[str, object]],
        scenarios: list[str] | None = None,
        mode: str = "enforce",
        repetitions: int = 1,
    ) -> tuple[int, str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            results = root / "results.json"
            baseline = root / "baseline.json"
            output = root / "evidence" / "aggregate.json"
            summary = root / "summary" / "aggregate.md"
            results.write_text(json.dumps({"reports": reports}))
            baseline.write_text(json.dumps({
                "scenarios": scenarios or ["navigation"],
                "mode": mode,
                "scenarioGoals": {
                    "real-card-play": {"maximumMissedDeadlineCount": 0, "maximumFrameMs": 20},
                },
                "goals": {
                    "minimumAverageFPS": 59,
                    "minimumOnePercentLowFPS": 59,
                    "maximumSevereStallCount": 0,
                },
            }))
            argv = [
                str(SCRIPT),
                "--results", str(results),
                "--output", str(output),
                "--summary", str(summary),
                "--expected-repetitions", str(repetitions),
                "--baseline", str(baseline),
            ]
            with patch.object(sys, "argv", argv), patch("builtins.print"):
                status = aggregate_performance.main()
            return status, summary.read_text()

    def test_missing_required_metrics_fail_closed(self) -> None:
        status, summary = self.run_aggregate([
            {"scenario": "navigation", "schemaVersion": 5, "iteration": 1}
        ])
        self.assertEqual(status, 1)
        self.assertIn("averageFPS is missing or non-numeric", summary)

    def test_missing_baseline_scenario_fails(self) -> None:
        status, summary = self.run_aggregate([report(scenario="other")])
        self.assertEqual(status, 1)
        self.assertIn("navigation: expected iterations 1..1, found []", summary)

    def test_deadline_and_max_frame_checks_remain_strict_only_for_battle_gestures(self) -> None:
        status, summary = self.run_aggregate([report(scenario="navigation", maxFrameMs=30, missedDeadlineCount=2)], ["navigation"])
        self.assertEqual(status, 0)
        self.assertNotIn("missed deadlines", summary)
        self.assertNotIn("max frame ms", summary)

        status, summary = self.run_aggregate([report(scenario="real-card-play", maxFrameMs=30, missedDeadlineCount=2)], ["real-card-play"])
        self.assertEqual(status, 1)
        self.assertIn("missed deadlines", summary)
        self.assertIn("max frame ms 30.00 above 20.00", summary)

    def test_observe_mode_reports_each_bad_repetition_but_rejects_invalid_evidence(self) -> None:
        reports = [report(iteration=n) for n in range(1, 6)]
        reports[-1]["onePercentLowFPS"] = 10
        status, summary = self.run_aggregate(reports, mode="observe", repetitions=5)
        self.assertEqual(status, 0)
        self.assertIn("navigation repetition 5: 1% low", summary)
        status, _ = self.run_aggregate(reports, mode="enforce", repetitions=5)
        self.assertEqual(status, 1)
        reports[-1]["iteration"] = 4
        status, summary = self.run_aggregate(reports, mode="observe", repetitions=5)
        self.assertEqual(status, 1)
        self.assertIn("expected iterations", summary)


if __name__ == "__main__":
    unittest.main()
