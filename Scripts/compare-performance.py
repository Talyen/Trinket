#!/usr/bin/env python3
"""Compare repeated Battle frame reports with goals and an optional calibrated reference."""

from __future__ import annotations

import argparse
import json
import statistics
from pathlib import Path
from typing import Any


def median(records: list[dict[str, Any]], key: str) -> float:
    return statistics.median(float(record[key]) for record in records)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--results", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    args = parser.parse_args()

    baseline = json.loads(args.baseline.read_text())
    reports = json.loads(args.results.read_text()).get("reports", [])
    grouped: dict[str, list[dict[str, Any]]] = {}
    for report in reports:
        grouped.setdefault(str(report["scenario"]), []).append(report)

    goals = baseline["goals"]
    reference = baseline.get("reference", {})
    minimum_iterations = int(baseline.get("minimumIterations", 5))
    failures: list[str] = []
    rows: list[str] = []
    for scenario in baseline["scenarios"]:
        records = grouped.get(scenario, [])
        if len(records) < minimum_iterations:
            failures.append(f"{scenario}: expected {minimum_iterations} iterations, found {len(records)}")
            continue

        values = {
            "averageFPS": median(records, "averageFPS"),
            "onePercentLowFPS": median(records, "onePercentLowFPS"),
            "pointOnePercentLowFPS": median(records, "pointOnePercentLowFPS"),
            "p99FrameMs": median(records, "p99FrameMs"),
            "missedDeadlineRatio": median(records, "missedDeadlineRatio"),
            "severeStallCount": median(records, "severeStallCount"),
        }
        rows.append(
            f"| {scenario} | {len(records)} | {values['averageFPS']:.2f} | "
            f"{values['onePercentLowFPS']:.2f} | {values['pointOnePercentLowFPS']:.2f} | "
            f"{values['p99FrameMs']:.2f} | {values['missedDeadlineRatio']:.4%} | "
            f"{values['severeStallCount']:.1f} |"
        )

        if values["averageFPS"] < float(goals["minimumAverageFPS"]):
            failures.append(f"{scenario}: median average FPS {values['averageFPS']:.2f} below goal")
        if values["onePercentLowFPS"] < float(goals["minimumOnePercentLowFPS"]):
            failures.append(f"{scenario}: median 1% low {values['onePercentLowFPS']:.2f} FPS below goal")
        if values["pointOnePercentLowFPS"] < float(goals["minimumPointOnePercentLowFPS"]):
            failures.append(f"{scenario}: median 0.1% low {values['pointOnePercentLowFPS']:.2f} FPS below goal")
        if values["p99FrameMs"] > float(goals["maximumP99FrameMs"]):
            failures.append(f"{scenario}: median p99 {values['p99FrameMs']:.2f}ms above goal")
        if values["missedDeadlineRatio"] > float(goals["maximumMissedDeadlineRatio"]):
            failures.append(f"{scenario}: median missed ratio {values['missedDeadlineRatio']:.4%} above goal")
        if values["severeStallCount"] > float(goals["maximumSevereStallCount"]):
            failures.append(f"{scenario}: median severe stalls {values['severeStallCount']:.1f} above goal")

        scenario_reference = reference.get(scenario)
        if scenario_reference:
            regression_limit = float(baseline["maximumRegressionPercent"]) / 100.0
            if values["p99FrameMs"] > float(scenario_reference["p99FrameMs"]) * (1 + regression_limit):
                failures.append(f"{scenario}: p99 regressed more than the calibrated limit")
            if values["missedDeadlineRatio"] > max(
                float(scenario_reference["missedDeadlineRatio"]) * (1 + regression_limit),
                float(baseline["absoluteMissedRatioRegressionFloor"]),
            ):
                failures.append(f"{scenario}: missed-deadline ratio regressed beyond the calibrated limit")

    mode = str(baseline.get("mode", "observe"))
    lines = [
        "# Battle performance comparison",
        "",
        f"Mode: `{mode}`. Refresh target: `{baseline['refreshTargetHz']} Hz`.",
        "",
        "| Scenario | Iterations | Median avg FPS | Median 1% low | Median 0.1% low | Median p99 ms | Median missed | Median severe |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
        *rows,
        "",
        "## Findings",
        "",
    ]
    lines.extend(f"- {failure}" for failure in failures)
    if not failures:
        lines.append("- No goal or calibrated-baseline regressions detected.")
    if mode == "observe":
        lines.extend([
            "",
            "Calibration mode is non-blocking. Promote to `enforce` only after the reference "
            "contains repeated runs from the pinned CI simulator and Xcode version.",
        ])

    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 1 if failures and mode == "enforce" else 0


if __name__ == "__main__":
    raise SystemExit(main())
