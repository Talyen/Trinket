#!/usr/bin/env python3
"""Aggregate repeated app performance reports with robust medians and spread."""

from __future__ import annotations

import argparse
import json
import math
import statistics
from pathlib import Path
from typing import Any


METRICS = (
    "averageFPS",
    "onePercentLowFPS",
    "p95FrameMs",
    "p99FrameMs",
    "maxFrameMs",
    "missedDeadlineCount",
    "missedDeadlineRatio",
    "severeStallCount",
)

COUNT_METRICS = {"missedDeadlineCount", "severeStallCount"}
NON_NEGATIVE_METRICS = {
    "averageFPS",
    "onePercentLowFPS",
    "p95FrameMs",
    "p99FrameMs",
    "maxFrameMs",
    "missedDeadlineCount",
    "severeStallCount",
}
REQUIRED_SCHEMA_VERSION = 4


def aggregate(values: list[float]) -> dict[str, float]:
    median = statistics.median(values)
    deviations = [abs(value - median) for value in values]
    return {
        "median": median,
        "mad": statistics.median(deviations),
        "minimum": min(values),
        "maximum": max(values),
    }


def validate_report(report: object, expected_scenarios: set[str]) -> tuple[dict[str, Any] | None, list[str]]:
    if not isinstance(report, dict):
        return None, ["report is not an object"]
    scenario = report.get("scenario")
    failures: list[str] = []
    if not isinstance(scenario, str) or scenario not in expected_scenarios:
        failures.append(f"unexpected or missing scenario {scenario!r}")
        return None, failures
    if report.get("schemaVersion") != REQUIRED_SCHEMA_VERSION:
        failures.append(
            f"{scenario}: expected frame report schema {REQUIRED_SCHEMA_VERSION}, "
            f"found {report.get('schemaVersion')!r}"
        )
    iteration = report.get("iteration")
    if isinstance(iteration, bool) or not isinstance(iteration, int) or iteration < 1:
        failures.append(f"{scenario}: iteration must be a positive integer")
    for metric in METRICS:
        value = report.get(metric)
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            failures.append(f"{scenario}: {metric} is missing or non-numeric")
            continue
        numeric = float(value)
        if not math.isfinite(numeric):
            failures.append(f"{scenario}: {metric} is not finite")
            continue
        if metric in COUNT_METRICS and (not numeric.is_integer() or numeric < 0):
            failures.append(f"{scenario}: {metric} must be a non-negative integer")
        elif metric in NON_NEGATIVE_METRICS and numeric < 0:
            failures.append(f"{scenario}: {metric} must be non-negative")
        elif metric == "missedDeadlineRatio" and not 0 <= numeric <= 1:
            failures.append(f"{scenario}: missedDeadlineRatio must be between 0 and 1")
    return report, failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--results", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    parser.add_argument("--expected-repetitions", required=True, type=int)
    parser.add_argument("--baseline", required=True, type=Path)
    args = parser.parse_args()

    if args.expected_repetitions < 1:
        parser.error("--expected-repetitions must be a positive integer")

    payload = json.loads(args.results.read_text())
    reports = payload.get("reports", [])
    if not isinstance(reports, list):
        raise SystemExit("results payload must contain a reports array")
    baseline = json.loads(args.baseline.read_text())
    scenarios_value = baseline.get("scenarios")
    if not isinstance(scenarios_value, list) or not scenarios_value or any(
        not isinstance(value, str) or not value for value in scenarios_value
    ):
        raise SystemExit("baseline must contain a non-empty scenarios array")
    expected_scenarios = set(scenarios_value)
    if len(expected_scenarios) != len(scenarios_value):
        raise SystemExit("baseline scenarios must be unique")
    try:
        goals = baseline["goals"]
        minimum_average = float(goals["minimumAverageFPS"])
        minimum_low = float(goals["minimumOnePercentLowFPS"])
        maximum_severe = float(goals["maximumSevereStallCount"])
    except (KeyError, TypeError, ValueError) as error:
        raise SystemExit(f"baseline goals are invalid: {error}") from error
    if not all(math.isfinite(value) and value >= 0 for value in (minimum_average, minimum_low, maximum_severe)):
        raise SystemExit("baseline goals must be finite and non-negative")

    grouped: dict[str, list[dict[str, Any]]] = {scenario: [] for scenario in scenarios_value}

    failures: list[str] = []
    for index, raw_report in enumerate(reports, 1):
        report, report_failures = validate_report(raw_report, expected_scenarios)
        if report_failures:
            failures.extend(f"report {index}: {failure}" for failure in report_failures)
        if report is not None and not report_failures:
            grouped[report["scenario"]].append(report)

    scenarios: dict[str, Any] = {}
    for scenario in scenarios_value:
        records = grouped[scenario]
        records.sort(key=lambda item: int(item.get("iteration", 0)))
        if len(records) != args.expected_repetitions:
            failures.append(
                f"{scenario}: expected {args.expected_repetitions} reports, found {len(records)}"
            )
        suite = str(records[0].get("suite", "unknown")) if records else "unknown"
        expected_iterations = set(range(1, args.expected_repetitions + 1))
        actual_iterations = [record["iteration"] for record in records]
        if set(actual_iterations) != expected_iterations or len(actual_iterations) != len(set(actual_iterations)):
            failures.append(
                f"{scenario}: expected iterations 1..{args.expected_repetitions}, "
                f"found {actual_iterations}"
            )
        for record in records:
            repetition = int(record["iteration"])
            if float(record["averageFPS"]) < minimum_average:
                failures.append(
                    f"{scenario} repetition {repetition}: average FPS below {minimum_average:g}"
                )
            if float(record["onePercentLowFPS"]) < minimum_low:
                failures.append(
                    f"{scenario} repetition {repetition}: 1% low below {minimum_low:g} FPS"
                )
            if float(record["severeStallCount"]) > maximum_severe:
                failures.append(
                    f"{scenario} repetition {repetition}: severe stalls above {maximum_severe:g}"
                )
            if scenario in {"real-card-play", "hand-drag-cancel"}:
                if int(record["missedDeadlineCount"]) != 0:
                    failures.append(f"{scenario} repetition {repetition}: missed display deadline")
                if float(record["maxFrameMs"]) > 20:
                    failures.append(f"{scenario} repetition {repetition}: max frame exceeded 20 ms")
        metrics: dict[str, Any] = {}
        for metric in METRICS:
            values = [float(record[metric]) for record in records if metric in record]
            if values:
                metrics[metric] = aggregate(values)
        scenarios[scenario] = {
            "suite": suite,
            "repetitionCount": len(records),
            "metrics": metrics,
            "iterations": records,
        }

    output = {
        "schemaVersion": 1,
        "expectedRepetitions": args.expected_repetitions,
        "scenarios": scenarios,
        "failures": failures,
    }
    args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")

    lines = [
        "# Repeated performance summary",
        "",
        "| Scenario | Runs | Median 1% low | MAD | Median max ms | Missed deadlines |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for scenario, data in scenarios.items():
        metrics = data["metrics"]
        low = metrics.get("onePercentLowFPS", {})
        maximum = metrics.get("maxFrameMs", {})
        missed = metrics.get("missedDeadlineCount", {})
        lines.append(
            f"| {scenario} | {data['repetitionCount']} | {low.get('median', 0):.2f} | "
            f"{low.get('mad', 0):.2f} | {maximum.get('median', 0):.2f} | "
            f"{missed.get('maximum', 0):.0f} |"
        )
    if failures:
        lines.extend(["", "## Failures", "", *(f"- {failure}" for failure in failures)])
    args.summary.write_text("\n".join(lines) + "\n")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
