#!/usr/bin/env python3

from __future__ import annotations

import math
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from script_test_support import ROOT, load_script, write_json
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
            write_json(
                baseline,
                {
                    **({"mode": mode} if mode is not None else {}),
                    "goals": goals or {"minimumAverageFPS": 59, "minimumOnePercentLowFPS": 59, "maximumSevereStallCount": 0},
                    "refreshTargetHz": 60,
                    "scenarios": ["navigation"],
                },
            )
            write_json(results, {"reports": reports})
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

    def test_duplicate_reports_fail(self) -> None:
        status, summary = self.run_comparison([report(), report()])
        self.assertEqual(status, 1)
        self.assertIn("expected iterations 1..1", summary)

    def test_inconsistent_interaction_metrics_fail_even_in_observe_mode(self) -> None:
        for overrides, reason in (
            ({"sampleCount": 2, "missedDeadlineCount": 3}, "missed deadlines <= sample count"),
            ({"severeStallCount": 26}, "severe stalls <= missed deadlines"),
            ({"missedDeadlineCount": 0, "missedDeadlineRatio": 0, "severeStallCount": 5},
             "severe stalls <= missed deadlines"),
            ({"missedDeadlineRatio": 0.4}, "missedDeadlineRatio does not match"),
            ({"p95FrameMs": 100, "p99FrameMs": 10}, "p95 frame time <= p99 frame time"),
            ({"p99FrameMs": 121}, "p99 frame time <= maximum frame time"),
        ):
            with self.subTest(overrides=overrides):
                status, summary = self.run_comparison([report(schemaVersion=6, **overrides)], mode="observe")
                self.assertEqual(status, 1)
                self.assertIn("coverage failure", summary)
                self.assertIn(reason, summary)
                self.assertNotIn("| navigation |", summary)

    def test_interaction_metric_consistency_accepts_equal_counts_and_rounded_ratios(self) -> None:
        for overrides in (
            {"sampleCount": 25, "missedDeadlineCount": 25, "severeStallCount": 25, "missedDeadlineRatio": 1,
             "estimatedMissedFrameCount": 50, "averageFPS": 20, "onePercentLowFPS": 20,
             "p95FrameMs": 50, "p99FrameMs": 50, "maxFrameMs": 50,
             "measurementDuration": 1.25, "captureEndedAt": 101.25},
            {"missedDeadlineCount": 25, "estimatedMissedFrameCount": 25, "missedDeadlineRatio": 0.208333},
        ):
            status, summary = self.run_comparison([report(schemaVersion=6, **overrides)], mode="observe")
            self.assertEqual(status, 0)
            self.assertNotIn("coverage failure", summary)

    def test_interaction_frame_statistics_must_be_physically_possible(self) -> None:
        for overrides, reason in (
            ({"averageFPS": 0}, "frame rates and frame times must be positive"),
            ({"onePercentLowFPS": 0}, "frame rates and frame times must be positive"),
            ({"p95FrameMs": 0}, "frame rates and frame times must be positive"),
            ({"onePercentLowFPS": 70}, "1% low FPS cannot exceed average FPS"),
            ({"averageFPS": 5, "onePercentLowFPS": 5}, "average FPS is incompatible with maximum frame time"),
        ):
            with self.subTest(overrides=overrides):
                status, summary = self.run_comparison([report(schemaVersion=6, **overrides)], mode="observe")
                self.assertEqual(status, 1)
                self.assertIn(reason, summary)

        status, _ = self.run_comparison([report(schemaVersion=6, averageFPS=10, onePercentLowFPS=10,
                                                 p95FrameMs=100, p99FrameMs=100, maxFrameMs=100,
                                                 measurementDuration=12, captureEndedAt=112)], mode="observe")
        self.assertEqual(status, 0)

    def test_interaction_evidence_rejects_impossible_sampled_metrics(self) -> None:
        for overrides, reason in (
            ({"averageFPS": 59, "onePercentLowFPS": 59}, "sampled intervals exceed the capture duration"),
            ({"onePercentLowFPS": 10}, "1% low FPS is incompatible with maximum frame time"),
            ({"p99FrameMs": 20, "maxFrameMs": 20}, "1% low FPS is incompatible with p99 frame time"),
            ({"estimatedMissedFrameCount": -1}, "estimated missed frames must be a non-negative integer"),
            ({"estimatedMissedFrameCount": 0.5}, "estimated missed frames must be a non-negative integer"),
            ({"estimatedMissedFrameCount": None}, "estimatedMissedFrameCount is missing or non-numeric"),
        ):
            with self.subTest(overrides=overrides):
                status, summary = self.run_comparison([report(schemaVersion=6, **overrides)], mode="observe")
                self.assertEqual(status, 1)
                self.assertIn(reason, summary)

    def test_consistency_accepts_actual_sampler_statistics_at_percentile_boundaries(self) -> None:
        from internal.performance.performance_model import validate_report
        for count in (1, 2, 99, 100, 101, 200):
            intervals = sorted([1 / 60] * (count - 1) + [0.08])
            worst = intervals[-math.ceil(count * 0.01):]
            missed = sum(interval >= 1.5 / 60 for interval in intervals)
            severe = sum(interval >= 3 / 60 for interval in intervals)
            estimated = sum(max(0, math.floor(interval * 60 + 0.5) - 1) for interval in intervals)
            duration = sum(intervals) + 0.001
            measured = report(
                schemaVersion=6, sampleCount=count, measurementDuration=duration, captureEndedAt=100 + duration,
                averageFPS=count / sum(intervals), onePercentLowFPS=len(worst) / sum(worst),
                p95FrameMs=1000 * intervals[math.ceil(count * 0.95) - 1],
                p99FrameMs=1000 * intervals[math.ceil(count * 0.99) - 1], maxFrameMs=80,
                missedDeadlineCount=missed, severeStallCount=severe,
                estimatedMissedFrameCount=estimated, missedDeadlineRatio=missed / count,
            )
            with self.subTest(count=count):
                self.assertEqual(validate_report(measured), [])

    def test_device_baseline_requires_current_interaction_reports(self) -> None:
        from internal.cli import read_json
        from internal.performance.performance_model import validate_report
        baseline = read_json(ROOT / 'Performance/Baselines/device-120.json')
        self.assertTrue(any('legacy report' in failure for failure in validate_report(report(), baseline)))

    def test_legacy_metrics_do_not_require_current_interaction_consistency(self) -> None:
        status, summary = self.run_comparison([report(missedDeadlineRatio=0.4)], mode="observe")
        self.assertEqual(status, 0)
        self.assertNotIn("coverage failure", summary)

    def test_removed_and_malformed_metrics_fail(self) -> None:
        status, summary = self.run_comparison([
            report(pointOnePercentLowFPS=58, averageFPS="fast")
        ])
        self.assertEqual(status, 1)
        self.assertIn("removed metrics still present", summary)
        self.assertIn("averageFPS is missing or non-numeric", summary)

    def test_only_gate_metrics_fail(self) -> None:
        status, summary = self.run_comparison([
            report(averageFPS=54.9, onePercentLowFPS=53.8, severeStallCount=3)
        ], goals={"minimumAverageFPS": 55, "minimumOnePercentLowFPS": 54, "maximumSevereStallCount": 2})
        self.assertEqual(status, 1)
        self.assertIn("average FPS 54.90 below 55.00", summary)
        self.assertIn("1% low 53.80 below 54.00", summary)
        self.assertIn("severe stalls 3.00 above 2.00", summary)

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

    def test_invalid_evidence_fails_even_in_observe_mode(self) -> None:
        for reports in ([], [report(schemaVersion="unknown")], [report(schemaVersion=4)], [report(iteration=True)],
                        [report(averageFPS=float("nan"))], [report(missedDeadlineCount=-1)],
                        [report(missedDeadlineRatio=2)], [report(schemaVersion=6.0)],
                        [report(averageFPS=10 ** 400)]):
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

    def test_malformed_baseline_cannot_disable_performance_goals(self) -> None:
        from internal.performance.performance_model import load_baseline
        baseline = {"scenarios": ["navigation"], "goals": {
            "minimumAverageFPS": 59, "minimumOnePercentLowFPS": 59, "maximumSevereStallCount": 0,
        }}
        for invalid in (None, baseline | {"goals": []},
                        baseline | {"goals": baseline["goals"] | {"minimumAverageFPS": True}},
                        baseline | {"scenarioGoals": {"navigation": {"maximumFrameMs": float("nan")}}},
                        baseline | {"scenarioGoals": {"navigaton": {"maximumFrameMs": 20}}},
                        baseline | {"refreshTargetHz": "sixty"}, baseline | {"minimumReportSchema": True},
                        baseline | {"goals": baseline["goals"] | {"maximumFrameMS": 20}},
                        baseline | {"goals": baseline["goals"] | {"minimumAverageFPS": 10 ** 400}}):
            with self.subTest(baseline=invalid), self.assertRaises(SystemExit):
                load_baseline(invalid)


if __name__ == "__main__":
    unittest.main()
