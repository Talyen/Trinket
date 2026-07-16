#!/usr/bin/env python3
"""Validate one measured frame-pacing report per maintained scenario."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


REQUIRED_NUMERIC_FIELDS = (
    "averageFPS",
    "onePercentLowFPS",
    "p95FrameMs",
    "p99FrameMs",
    "maxFrameMs",
    "missedDeadlineCount",
    "missedDeadlineRatio",
    "severeStallCount",
)
REMOVED_FIELDS = ("p999FrameMs", "pointOnePercentLowFPS")


def finite_number(report: dict[str, Any], key: str) -> float:
    value = report.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{key} is missing or non-numeric")
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(f"{key} is not finite")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--results", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    args = parser.parse_args()

    baseline = json.loads(args.baseline.read_text())
    payload = json.loads(args.results.read_text())
    reports = payload.get("reports")
    if not isinstance(reports, list):
        raise SystemExit("results payload must contain a reports array")

    scenarios = [str(value) for value in baseline["scenarios"]]
    expected = set(scenarios)
    grouped: dict[str, list[dict[str, Any]]] = {scenario: [] for scenario in scenarios}
    failures: list[str] = []

    for index, raw_report in enumerate(reports):
        if not isinstance(raw_report, dict):
            failures.append(f"report {index + 1}: expected an object")
            continue
        scenario = raw_report.get("scenario")
        if not isinstance(scenario, str) or scenario not in expected:
            failures.append(f"report {index + 1}: unexpected or missing scenario {scenario!r}")
            continue
        grouped[scenario].append(raw_report)

    goals = baseline["goals"]
    rows: list[str] = []
    for scenario in scenarios:
        records = grouped[scenario]
        if len(records) != 1:
            failures.append(f"{scenario}: expected exactly one measured report, found {len(records)}")
            continue

        report = records[0]
        if report.get("schemaVersion") != 4:
            failures.append(
                f"{scenario}: expected frame report schema 4, found {report.get('schemaVersion')!r}"
            )
        if report.get("iteration") != 1:
            failures.append(
                f"{scenario}: expected measured iteration 1, found {report.get('iteration')!r}"
            )
        removed = [key for key in REMOVED_FIELDS if key in report]
        if removed:
            failures.append(f"{scenario}: removed metrics still present: {', '.join(removed)}")

        try:
            values = {key: finite_number(report, key) for key in REQUIRED_NUMERIC_FIELDS}
        except ValueError as error:
            failures.append(f"{scenario}: {error}")
            continue

        rows.append(
            f"| {scenario} | {values['averageFPS']:.2f} | "
            f"{values['onePercentLowFPS']:.2f} | {values['p95FrameMs']:.2f} | "
            f"{values['p99FrameMs']:.2f} | {values['maxFrameMs']:.2f} | "
            f"{values['missedDeadlineRatio']:.4%} | {int(values['severeStallCount'])} |"
        )

        if values["averageFPS"] < float(goals["minimumAverageFPS"]):
            failures.append(f"{scenario}: average FPS {values['averageFPS']:.2f} below 59.00")
        if values["onePercentLowFPS"] < float(goals["minimumOnePercentLowFPS"]):
            failures.append(f"{scenario}: 1% low {values['onePercentLowFPS']:.2f} FPS below 59.00")
        if values["severeStallCount"] > float(goals["maximumSevereStallCount"]):
            failures.append(
                f"{scenario}: severe stalls {int(values['severeStallCount'])} above zero"
            )

    lines = [
        "# App performance comparison",
        "",
        "Gate: one measured report per scenario; average FPS >= 59; 1% low FPS >= 59; severe stalls = 0.",
        "p95/p99/max frame time and missed deadlines are diagnostic only.",
        "",
        "| Scenario | Avg FPS | 1% low | p95 ms | p99 ms | Max ms | Missed | Severe |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
        *rows,
        "",
        "## Findings",
        "",
    ]
    lines.extend(f"- {failure}" for failure in failures)
    if not failures:
        lines.append("- Every maintained scenario met the 59/59/zero-severe-stall gate.")

    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
