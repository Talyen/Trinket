#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).parents[1] / "aggregate-performance-results.py"
SPEC = importlib.util.spec_from_file_location("aggregate_performance", SCRIPT)
assert SPEC and SPEC.loader
aggregate_performance = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(aggregate_performance)


class AggregatePerformanceTests(unittest.TestCase):
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
            output = root / "aggregate.json"
            summary = root / "aggregate.md"
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
            with patch.object(sys, "argv", argv):
                status = aggregate_performance.main()
            return status, summary.read_text()

    def test_missing_required_metrics_fail_closed(self) -> None:
        status, summary = self.run_aggregate([
            {"scenario": "navigation", "schemaVersion": 5, "iteration": 1}
        ])
        self.assertEqual(status, 1)
        self.assertIn("averageFPS is missing or non-numeric", summary)

    def test_missing_baseline_scenario_fails(self) -> None:
        report = {
            "scenario": "other",
            "schemaVersion": 5,
            "iteration": 1,
            "averageFPS": 60,
            "onePercentLowFPS": 60,
            "p95FrameMs": 1,
            "p99FrameMs": 1,
            "maxFrameMs": 1,
            "missedDeadlineCount": 0,
            "missedDeadlineRatio": 0,
            "severeStallCount": 0,
        }
        status, summary = self.run_aggregate([report])
        self.assertEqual(status, 1)
        self.assertIn("navigation: expected 1 reports, found 0", summary)

    def test_deadline_and_max_frame_checks_remain_strict_only_for_battle_gestures(self) -> None:
        def report(scenario: str) -> dict[str, object]:
            return {
                "scenario": scenario,
                "schemaVersion": 5,
                "iteration": 1,
                "averageFPS": 60,
                "onePercentLowFPS": 60,
                "p95FrameMs": 10,
                "p99FrameMs": 10,
                "maxFrameMs": 30,
                "missedDeadlineCount": 2,
                "missedDeadlineRatio": 0.1,
                "severeStallCount": 0,
            }

        status, summary = self.run_aggregate([report("navigation")], ["navigation"])
        self.assertEqual(status, 0)
        self.assertNotIn("missed deadlines", summary)
        self.assertNotIn("max frame ms", summary)

        status, summary = self.run_aggregate([report("real-card-play")], ["real-card-play"])
        self.assertEqual(status, 1)
        self.assertIn("missed deadlines", summary)
        self.assertIn("max frame ms 30.00 above 20.00", summary)

    def test_observe_mode_reports_each_bad_repetition_but_rejects_invalid_evidence(self) -> None:
        report = {
            "scenario": "navigation", "schemaVersion": 5, "iteration": 1,
            "averageFPS": 60, "onePercentLowFPS": 60, "p95FrameMs": 16.7,
            "p99FrameMs": 16.7, "maxFrameMs": 16.7, "missedDeadlineCount": 0,
            "missedDeadlineRatio": 0, "severeStallCount": 0,
        }
        reports = [report | {"iteration": n} for n in range(1, 6)]
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
