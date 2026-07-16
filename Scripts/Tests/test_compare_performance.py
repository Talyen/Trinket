#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).parents[1] / "compare-performance.py"
SPEC = importlib.util.spec_from_file_location("compare_performance", SCRIPT)
assert SPEC and SPEC.loader
compare_performance = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(compare_performance)


class ComparePerformanceTests(unittest.TestCase):
    def run_comparison(self, reports: list[dict[str, object]]) -> tuple[int, str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            baseline = root / "baseline.json"
            results = root / "results.json"
            summary = root / "summary.md"
            baseline.write_text(json.dumps({
                "goals": {
                    "minimumAverageFPS": 59,
                    "minimumOnePercentLowFPS": 59,
                    "maximumSevereStallCount": 0,
                },
                "refreshTargetHz": 60,
                "scenarios": ["navigation"],
            }))
            results.write_text(json.dumps({"reports": reports}))
            argv = [
                str(SCRIPT),
                "--baseline", str(baseline),
                "--results", str(results),
                "--summary", str(summary),
            ]
            with patch.object(sys, "argv", argv):
                status = compare_performance.main()
            return status, summary.read_text()

    @staticmethod
    def report(**overrides: object) -> dict[str, object]:
        report: dict[str, object] = {
            "scenario": "navigation",
            "schemaVersion": 4,
            "iteration": 1,
            "averageFPS": 59.1,
            "onePercentLowFPS": 59.0,
            "p95FrameMs": 40.0,
            "p99FrameMs": 90.0,
            "maxFrameMs": 120.0,
            "missedDeadlineCount": 25,
            "missedDeadlineRatio": 0.4,
            "severeStallCount": 0,
        }
        report.update(overrides)
        return report

    def test_diagnostic_metrics_do_not_fail_gate(self) -> None:
        status, summary = self.run_comparison([self.report()])
        self.assertEqual(status, 0)
        self.assertIn("59/59/zero-severe-stall", summary)

    def test_duplicate_or_missing_reports_fail(self) -> None:
        status, summary = self.run_comparison([self.report(), self.report()])
        self.assertEqual(status, 1)
        self.assertIn("expected exactly one measured report, found 2", summary)

    def test_removed_and_malformed_metrics_fail(self) -> None:
        status, summary = self.run_comparison([
            self.report(pointOnePercentLowFPS=58, averageFPS="fast")
        ])
        self.assertEqual(status, 1)
        self.assertIn("removed metrics still present", summary)
        self.assertIn("averageFPS is missing or non-numeric", summary)

    def test_only_gate_metrics_fail(self) -> None:
        status, summary = self.run_comparison([
            self.report(averageFPS=58.9, onePercentLowFPS=58.8, severeStallCount=1)
        ])
        self.assertEqual(status, 1)
        self.assertIn("average FPS 58.90 below 59.00", summary)
        self.assertIn("1% low 58.80 FPS below 59.00", summary)
        self.assertIn("severe stalls 1 above zero", summary)


if __name__ == "__main__":
    unittest.main()
