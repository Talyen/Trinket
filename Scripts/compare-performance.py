#!/usr/bin/env python3
"""Validate one measured frame-pacing report per maintained scenario."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from performance_model import REQUIRED_NUMERIC_FIELDS, finite_number, load_baseline, validate_report, goal_findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--results", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    args = parser.parse_args()

    payload = json.loads(args.results.read_text())
    reports = payload.get("reports")
    if not isinstance(reports, list):
        raise SystemExit("results payload must contain a reports array")

    baseline = json.loads(args.baseline.read_text())
    scenarios, mode, minimum_average, minimum_low, maximum_severe = load_baseline(baseline)
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

    severe_limit_text = "zero" if maximum_severe == 0 else f"{maximum_severe:g}"
    findings: list[str] = []
    rows: list[str] = []
    for scenario in scenarios:
        records = grouped[scenario]
        if len(records) != 1:
            failures.append(f"{scenario}: expected exactly one measured report, found {len(records)}")
            continue

        report = records[0]
        failures.extend(validate_report(report))
        if report.get("iteration") != 1:
            failures.append(f"{scenario}: expected measured iteration 1, found {report.get('iteration')!r}")
        try:
            values = {key: finite_number(report, key) for key in REQUIRED_NUMERIC_FIELDS}
        except ValueError:
            continue

        rows.append(
            f"| {scenario} | {values['averageFPS']:.2f} | "
            f"{values['onePercentLowFPS']:.2f} | {values['p95FrameMs']:.2f} | "
            f"{values['p99FrameMs']:.2f} | {values['maxFrameMs']:.2f} | "
            f"{values['missedDeadlineRatio']:.4%} | {int(values['severeStallCount'])} |"
        )

        findings.extend(goal_findings(report, baseline))

    lines = [
        "# App performance comparison",
        "",
        f"Mode: `{mode}`. Refresh target: `{baseline.get('refreshTargetHz', 'unknown')} Hz`.",
        f"Gate: one measured report per scenario; average FPS >= {minimum_average:g}; "
        f"1% low FPS >= {minimum_low:g}; severe stalls <= {severe_limit_text}.",
        "Scenario-specific goals in the baseline also apply; p95/p99 are diagnostic.",
        "",
        "| Scenario | Avg FPS | 1% low | p95 ms | p99 ms | Max ms | Missed | Severe |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
        *rows,
        "",
        "## Findings",
        "",
    ]
    lines.extend(f"- Invalid evidence: {failure}" for failure in failures)
    lines.extend(f"- {finding}" for finding in findings)
    if not failures and not findings:
        lines.append("- Every maintained scenario met the configured goals.")
    if mode == "observe":
        lines.extend([
            "",
            "Calibration mode is non-blocking for performance findings; invalid evidence always fails. Promote to `enforce` only after local "
            "`performance.sh` Simulator runs consistently clear the goals.",
        ])

    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 1 if failures or (findings and mode == "enforce") else 0


if __name__ == "__main__":
    raise SystemExit(main())
