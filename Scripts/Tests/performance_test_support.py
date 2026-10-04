"""Representative frame report shared by comparison and repetition regressions."""

from __future__ import annotations


def report(**overrides: object) -> dict[str, object]:
    report: dict[str, object] = {
        "scenario": "navigation",
        "schemaVersion": 5,
        "iteration": 1,
        "step": "navigation",
        "completionStatus": "complete",
        "captureStartedAt": 100.0,
        "captureEndedAt": 102.0,
        "measurementDuration": 2.0,
        "sampleCount": 120,
        "expectedFPS": 60.0,
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
