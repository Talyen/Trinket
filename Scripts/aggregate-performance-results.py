#!/usr/bin/env python3
"""Aggregate repeated app performance reports with robust medians and spread."""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from internal.cli import read_json
from internal.performance.performance_model import METRICS, load_baseline, load_results_reports, validate_report, goal_findings, group_reports_by_scenario


def aggregate(values: list[float]) -> dict[str, float]:
    median = statistics.median(values)
    deviations = [abs(value - median) for value in values]
    return {
        "median": median,
        "mad": statistics.median(deviations),
        "minimum": min(values),
        "maximum": max(values),
    }


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

    payload = read_json(args.results)
    reports = load_results_reports(payload)
    baseline = read_json(args.baseline)
    scenarios_value, mode, _, _, _ = load_baseline(baseline)
    grouped, failures = group_reports_by_scenario(reports, scenarios_value)
    for scenario, records in grouped.items():
        valid = []
        for record in records:
            report_failures = validate_report(record, baseline)
            failures.extend(report_failures)
            if not report_failures:
                valid.append(record)
        grouped[scenario] = valid

    findings: list[str] = []
    scenarios: dict[str, Any] = {}
    for scenario in scenarios_value:
        records = grouped[scenario]
        records.sort(key=lambda item: item["iteration"])
        if len(records) != args.expected_repetitions:
            failures.append(
                f"{scenario}: expected {args.expected_repetitions} reports, found {len(records)}"
            )
        suite = str(records[0].get("suite", "unknown")) if records else "unknown"
        actual_iterations = [record["iteration"] for record in records]
        if actual_iterations != list(range(1, args.expected_repetitions + 1)):
            failures.append(
                f"{scenario}: expected iterations 1..{args.expected_repetitions}, "
                f"found {actual_iterations}"
            )
        for record in records:
            findings.extend(goal_findings(record, baseline))
        metrics: dict[str, Any] = {}
        for metric in METRICS:
            values = [float(record[metric]) for record in records]
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
        "mode": mode,
        "failures": failures,
        "findings": findings,
    }
    args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")

    status = "coverage failure" if failures else ("performance finding" if findings else "clean observation")
    lines = [
        f"Status: **{status}**",
        "# Repeated performance summary",
        f"Mode: `{mode}`. Every repetition is evaluated against the baseline goals.",
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
    if findings:
        lines.extend(["", "## Performance findings", "", *(f"- {finding}" for finding in findings)])
    if mode == "observe":
        lines.extend(["", "Calibration mode is non-blocking for performance findings; invalid evidence always fails."])
    print("\n".join(lines))
    args.summary.write_text("\n".join(lines) + "\n")
    return 1 if failures or (findings and mode == "enforce") else 0


if __name__ == "__main__":
    raise SystemExit(main())
