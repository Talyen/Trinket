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
    def run_comparison(
        self,
        reports: list[dict[str, object]],
        *,
        mode: str = "enforce",
        goals: dict[str, object] | None = None,
    ) -> tuple[int, str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            baseline = root / "baseline.json"
            results = root / "results.json"
            summary = root / "summary.md"
            baseline.write_text(json.dumps({
                "mode": mode,
                "goals": goals or {
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
            "schemaVersion": 5,
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
        self.assertIn("configured goals", summary)
        self.assertIn("Mode: `enforce`", summary)

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
        self.assertIn("1% low 58.80 below 59.00", summary)
        self.assertIn("severe stalls 1.00 above 0.00", summary)

    def test_observe_mode_is_non_blocking(self) -> None:
        status, summary = self.run_comparison(
            [self.report(averageFPS=40.0, onePercentLowFPS=1.5, severeStallCount=10)],
            mode="observe",
        )
        self.assertEqual(status, 0)
        self.assertIn("Mode: `observe`", summary)
        self.assertIn("average FPS 40.00 below 59.00", summary)
        self.assertIn("Calibration mode is non-blocking", summary)

    def test_default_mode_is_observe(self) -> None:
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
            results.write_text(json.dumps({
                "reports": [self.report(averageFPS=40.0, onePercentLowFPS=1.5, severeStallCount=1)],
            }))
            argv = [
                str(SCRIPT),
                "--baseline", str(baseline),
                "--results", str(results),
                "--summary", str(summary),
            ]
            with patch.object(sys, "argv", argv):
                status = compare_performance.main()
            rendered = summary.read_text()
            self.assertEqual(status, 0)
            self.assertIn("Mode: `observe`", rendered)
            self.assertIn("Calibration mode is non-blocking", rendered)

    def test_configured_goals_and_metric_domains_are_enforced(self) -> None:
        status, rendered = self.run_comparison(
            [self.report(
                averageFPS=54.9,
                onePercentLowFPS=53.9,
                missedDeadlineCount=-1,
                missedDeadlineRatio=2,
                severeStallCount=3,
            )],
            mode="enforce",
            goals={
                "minimumAverageFPS": 55,
                "minimumOnePercentLowFPS": 54,
                "maximumSevereStallCount": 2,
            },
        )
        self.assertEqual(status, 1)
        self.assertIn("below 55.00", rendered)
        self.assertIn("must be a non-negative integer", rendered)
        self.assertIn("must be between 0 and 1", rendered)
        self.assertIn("above 2", rendered)

    def test_invalid_evidence_fails_even_in_observe_mode(self) -> None:
        for reports in ([], [self.report(schemaVersion=4)], [self.report(iteration=True)],
                        [self.report(averageFPS=float("nan"))]):
            with self.subTest(reports=reports):
                status, _ = self.run_comparison(reports, mode="observe")
                self.assertEqual(status, 1)

    def test_report_schema_matches_swift_producer(self) -> None:
        import re
        producer = SCRIPT.parents[1] / "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/FramePacing.swift"
        match = re.search(r"static let schemaVersion = (\d+)", producer.read_text())
        self.assertIsNotNone(match)
        status, _ = self.run_comparison([self.report(schemaVersion=int(match.group(1)))])
        self.assertEqual(status, 0)


if __name__ == "__main__":
    unittest.main()
