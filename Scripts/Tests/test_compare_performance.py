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
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from script_test_support import ROOT, load_script
from performance_test_support import report


SCRIPT = ROOT / "Scripts/compare-performance.py"
compare_performance = load_script("compare_performance", "compare-performance.py")


class ComparePerformanceTests(unittest.TestCase):
    def run_comparison(
        self,
        reports: list[dict[str, object]],
        *,
        mode: str | None = "enforce",
        goals: dict[str, object] | None = None,
    ) -> tuple[int, str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            baseline = root / "baseline.json"
            results = root / "results.json"
            summary = root / "summary.md"
            baseline.write_text(json.dumps({
                **({"mode": mode} if mode is not None else {}),
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
            with patch.object(sys, "argv", argv), patch("builtins.print"):
                status = compare_performance.main()
            return status, summary.read_text()


    def test_interaction_boundaries_and_completion_are_required(self) -> None:
        for overrides in (
            {"completionStatus": "timeout"}, {"completionStatus": "overflow"},
            {"sampleCount": 0}, {"expectedFPS": 120}, {"step": "wrong"}, {"captureEndedAt": 99},
            {"measurementDuration": 1}, {"captureStartedAt": None},
        ):
            status, summary = self.run_comparison([report(schemaVersion=6, **overrides)])
            self.assertEqual(status, 1)
            self.assertIn("coverage failure", summary)

    def test_diagnostic_metrics_do_not_fail_gate(self) -> None:
        status, summary = self.run_comparison([report()])
        self.assertEqual(status, 0)
        self.assertIn("configured goals", summary)
        self.assertIn("Mode: `enforce`", summary)

    def test_duplicate_or_missing_reports_fail(self) -> None:
        status, summary = self.run_comparison([report(), report()])
        self.assertEqual(status, 1)
        self.assertIn("expected exactly one measured report, found 2", summary)

    def test_removed_and_malformed_metrics_fail(self) -> None:
        status, summary = self.run_comparison([
            report(pointOnePercentLowFPS=58, averageFPS="fast")
        ])
        self.assertEqual(status, 1)
        self.assertIn("removed metrics still present", summary)
        self.assertIn("averageFPS is missing or non-numeric", summary)

    def test_only_gate_metrics_fail(self) -> None:
        status, summary = self.run_comparison([
            report(averageFPS=58.9, onePercentLowFPS=58.8, severeStallCount=1)
        ])
        self.assertEqual(status, 1)
        self.assertIn("average FPS 58.90 below 59.00", summary)
        self.assertIn("1% low 58.80 below 59.00", summary)
        self.assertIn("severe stalls 1.00 above 0.00", summary)

    def test_observe_mode_is_non_blocking(self) -> None:
        for mode in ("observe", None):
            status, summary = self.run_comparison(
                [report(averageFPS=40.0, onePercentLowFPS=1.5, severeStallCount=10)],
                mode=mode,
            )
            self.assertEqual(status, 0)
            self.assertIn("Mode: `observe`", summary)
            self.assertIn("average FPS 40.00 below 59.00", summary)
            self.assertIn("Calibration mode is non-blocking", summary)

    def test_configured_goals_are_enforced(self) -> None:
        status, rendered = self.run_comparison(
            [report(
                averageFPS=54.9,
                onePercentLowFPS=53.9,
                missedDeadlineCount=1,
                missedDeadlineRatio=0.2,
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
        self.assertIn("above 2", rendered)

    def test_invalid_evidence_fails_even_in_observe_mode(self) -> None:
        for reports in ([], [report(schemaVersion="unknown")], [report(schemaVersion=4)], [report(iteration=True)],
                        [report(averageFPS=float("nan"))], [report(missedDeadlineCount=-1)],
                        [report(missedDeadlineRatio=2)], [report(schemaVersion=6.0)]):
            with self.subTest(reports=reports):
                status, summary = self.run_comparison(reports, mode="observe")
                self.assertEqual(status, 1)
                self.assertNotIn("| navigation |", summary, "invalid evidence must not appear as a measured result")
        for malformed in ({}, None):
            with self.subTest(payload=malformed), self.assertRaisesRegex(SystemExit, "reports array"):
                self.run_comparison(malformed, mode="observe")

    def test_report_schema_matches_swift_producer(self) -> None:
        import re
        producer = SCRIPT.parents[1] / "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Performance/FramePacing.swift"
        match = re.search(r"static let schemaVersion = (\d+)", producer.read_text())
        self.assertIsNotNone(match)
        status, _ = self.run_comparison([report(schemaVersion=int(match.group(1)))])
        self.assertEqual(status, 0)


if __name__ == "__main__":
    unittest.main()
