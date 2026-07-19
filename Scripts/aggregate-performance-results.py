#!/usr/bin/env python3
"""Aggregate repeated app performance reports with robust medians and spread."""

from __future__ import annotations

import argparse
import json
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
    args = parser.parse_args()

    payload = json.loads(args.results.read_text())
    reports = payload.get("reports", [])
    grouped: dict[str, list[dict[str, Any]]] = {}
    for report in reports:
        grouped.setdefault(str(report["scenario"]), []).append(report)

    failures: list[str] = []
    scenarios: dict[str, Any] = {}
    for scenario, records in sorted(grouped.items()):
        records.sort(key=lambda item: int(item.get("iteration", 0)))
        if len(records) != args.expected_repetitions:
            failures.append(
                f"{scenario}: expected {args.expected_repetitions} reports, found {len(records)}"
            )
        suite = str(records[0].get("suite", "unknown")) if records else "unknown"
        if scenario in {"real-card-play", "hand-drag-cancel"}:
            for record in records:
                repetition = int(record.get("iteration", 0))
                if float(record.get("onePercentLowFPS", 0)) < 59:
                    failures.append(f"{scenario} repetition {repetition}: 1% low below 59 FPS")
                if int(record.get("missedDeadlineCount", 0)) != 0:
                    failures.append(f"{scenario} repetition {repetition}: missed display deadline")
                if int(record.get("severeStallCount", 0)) != 0:
                    failures.append(f"{scenario} repetition {repetition}: severe stall")
                if float(record.get("maxFrameMs", 0)) > 20:
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
