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
                "--expected-repetitions", "1",
                "--baseline", str(baseline),
            ]
            with patch.object(sys, "argv", argv):
                status = aggregate_performance.main()
            return status, summary.read_text()

    def test_missing_required_metrics_fail_closed(self) -> None:
        status, summary = self.run_aggregate([
            {"scenario": "navigation", "schemaVersion": 4, "iteration": 1}
        ])
        self.assertEqual(status, 1)
        self.assertIn("averageFPS is missing or non-numeric", summary)

    def test_missing_baseline_scenario_fails(self) -> None:
        report = {
            "scenario": "other",
            "schemaVersion": 4,
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
                "schemaVersion": 4,
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
        self.assertNotIn("missed display deadline", summary)
        self.assertNotIn("max frame exceeded", summary)

        status, summary = self.run_aggregate([report("real-card-play")], ["real-card-play"])
        self.assertEqual(status, 1)
        self.assertIn("missed display deadline", summary)
        self.assertIn("max frame exceeded 20 ms", summary)


if __name__ == "__main__":
    unittest.main()
