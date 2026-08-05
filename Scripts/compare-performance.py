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


def validate_metric_domains(values: dict[str, float], scenario: str) -> list[str]:
    failures: list[str] = []
    for key in ("averageFPS", "onePercentLowFPS", "p95FrameMs", "p99FrameMs", "maxFrameMs"):
        if values[key] < 0:
            failures.append(f"{scenario}: {key} must be non-negative")
    for key in ("missedDeadlineCount", "severeStallCount"):
        if not values[key].is_integer() or values[key] < 0:
            failures.append(f"{scenario}: {key} must be a non-negative integer")
    ratio = values["missedDeadlineRatio"]
    if ratio < 0 or ratio > 1:
        failures.append(f"{scenario}: missedDeadlineRatio must be between 0 and 1")
    return failures


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

    mode = str(baseline.get("mode", "observe"))
    if mode not in ("observe", "enforce"):
        raise SystemExit(f"baseline mode must be 'observe' or 'enforce', found {mode!r}")

    goals = baseline["goals"]
    try:
        minimum_average = float(goals["minimumAverageFPS"])
        minimum_low = float(goals["minimumOnePercentLowFPS"])
        maximum_severe = float(goals["maximumSevereStallCount"])
    except (KeyError, TypeError, ValueError) as error:
        raise SystemExit(f"baseline goals are invalid: {error}") from error
    if not all(math.isfinite(value) for value in (minimum_average, minimum_low, maximum_severe)):
        raise SystemExit("baseline goals must be finite")
    if minimum_average < 0 or minimum_low < 0 or maximum_severe < 0:
        raise SystemExit("baseline goals must be non-negative")
    severe_limit_text = "zero" if maximum_severe == 0 else f"{maximum_severe:g}"
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

        failures.extend(validate_metric_domains(values, scenario))

        rows.append(
            f"| {scenario} | {values['averageFPS']:.2f} | "
            f"{values['onePercentLowFPS']:.2f} | {values['p95FrameMs']:.2f} | "
            f"{values['p99FrameMs']:.2f} | {values['maxFrameMs']:.2f} | "
            f"{values['missedDeadlineRatio']:.4%} | {int(values['severeStallCount'])} |"
        )

        if values["averageFPS"] < minimum_average:
            failures.append(
                f"{scenario}: average FPS {values['averageFPS']:.2f} below {minimum_average:.2f}"
            )
        if values["onePercentLowFPS"] < minimum_low:
            failures.append(
                f"{scenario}: 1% low {values['onePercentLowFPS']:.2f} FPS below {minimum_low:.2f}"
            )
        if values["severeStallCount"] > maximum_severe:
            failures.append(
                f"{scenario}: severe stalls {int(values['severeStallCount'])} above {severe_limit_text}"
            )

    lines = [
        "# App performance comparison",
        "",
        f"Mode: `{mode}`. Refresh target: `{baseline.get('refreshTargetHz', 'unknown')} Hz`.",
        f"Gate: one measured report per scenario; average FPS >= {minimum_average:g}; "
        f"1% low FPS >= {minimum_low:g}; severe stalls <= {severe_limit_text}.",
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
    if mode == "observe":
        lines.extend([
            "",
            "Calibration mode is non-blocking. Promote to `enforce` only after hosted "
            "Simulator runs consistently clear the goals.",
        ])

    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 1 if failures and mode == "enforce" else 0


if __name__ == "__main__":
    raise SystemExit(main())
