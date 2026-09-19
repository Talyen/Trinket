"""Shared schema and metric ownership for performance reports."""

from __future__ import annotations

import math
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
NON_NEGATIVE_METRICS = set(METRICS) - {"missedDeadlineRatio"}
REQUIRED_NUMERIC_FIELDS = METRICS
REMOVED_FIELDS = ("p999FrameMs", "pointOnePercentLowFPS")
REQUIRED_SCHEMA_VERSION = 6


def finite_number(report: dict[str, Any], key: str) -> float:
    value = report.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{key} is missing or non-numeric")
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(f"{key} is not finite")
    return result


def validate_report_domains(report: dict[str, Any]) -> list[str]:
    scenario = report.get("scenario")
    failures: list[str] = []
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
    return failures


def load_results_reports(payload: dict[str, Any]) -> list[dict[str, Any]]:
    """Extract the reports array from a collected results payload.

    Single source for the shape check previously restated in
    compare-performance.py and aggregate-performance-results.py.
    """
    reports = payload.get("reports")
    if not isinstance(reports, list):
        raise SystemExit("results payload must contain a reports array")
    return reports


def load_baseline(baseline: dict[str, Any]) -> tuple[list[str], str, float, float, float]:
    scenarios = baseline.get("scenarios")
    if not isinstance(scenarios, list) or not scenarios or any(
        not isinstance(value, str) or not value for value in scenarios
    ):
        raise SystemExit("baseline must contain a non-empty scenarios array")
    if len(set(scenarios)) != len(scenarios):
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
    mode = baseline.get("mode", "observe")
    if mode not in ("observe", "enforce"):
        raise SystemExit(f"baseline mode must be 'observe' or 'enforce', found {mode!r}")
    return scenarios, mode, minimum_average, minimum_low, maximum_severe


def group_reports_by_scenario(
    reports: list, scenarios: list[str]
) -> tuple[dict[str, list[dict[str, Any]]], list[str]]:
    """Group raw reports by maintained scenario; unknown/malformed entries fail.

    Single source for the grouping both aggregate (repeated runs) and compare
    (single report) used to copy-paste with different non-dict messages.
    """
    grouped: dict[str, list[dict[str, Any]]] = {scenario: [] for scenario in scenarios}
    failures: list[str] = []
    for index, raw_report in enumerate(reports, 1):
        if not isinstance(raw_report, dict):
            failures.append(f"report {index}: expected an object")
            continue
        scenario = raw_report.get("scenario")
        if not isinstance(scenario, str) or scenario not in grouped:
            failures.append(f"report {index}: unexpected or missing scenario {scenario!r}")
            continue
        grouped[scenario].append(raw_report)
    return grouped, failures


def validate_report(report: dict[str, Any], baseline: dict[str, Any] | None = None) -> list[str]:
    scenario = report.get("scenario")
    failures = validate_report_domains(report)
    if report.get("schemaVersion") not in (5, REQUIRED_SCHEMA_VERSION):
        failures.append(f"{scenario}: expected frame report schema {REQUIRED_SCHEMA_VERSION}, found {report.get('schemaVersion')!r}")
    iteration = report.get("iteration")
    if isinstance(iteration, bool) or not isinstance(iteration, int) or iteration < 1:
        failures.append(f"{scenario}: iteration must be a positive integer")
    if report.get("schemaVersion") == 6:
        if report.get("completionStatus") != "complete":
            failures.append(f"{scenario}: interaction capture is not complete")
        if report.get("step") != scenario:
            failures.append(f"{scenario}: missing or mismatched step identity")
        try:
            start = finite_number(report, "captureStartedAt")
            end = finite_number(report, "captureEndedAt")
            duration = finite_number(report, "measurementDuration")
            samples = finite_number(report, "sampleCount")
            expected_fps = finite_number(report, "expectedFPS")
            if expected_fps <= 0 or not samples.is_integer():
                failures.append(f"{scenario}: invalid cadence or sample count")
            if baseline and abs(expected_fps - float(baseline.get("refreshTargetHz", 60))) > 1:
                failures.append(f"{scenario}: incompatible observed refresh cadence")
            if end <= start or duration <= 0 or duration >= 60 or abs(end - start - duration) > 0.01 or samples <= 0:
                failures.append(f"{scenario}: invalid measurement boundaries or samples")
        except ValueError as error:
            failures.append(f"{scenario}: {error}")
    version = report.get("schemaVersion")
    if baseline and (not isinstance(version, int) or isinstance(version, bool) or version < baseline.get("minimumReportSchema", 5)):
        failures.append(f"{scenario}: legacy report cannot establish interaction coverage")
    removed = [key for key in REMOVED_FIELDS if key in report]
    if removed:
        failures.append(f"{scenario}: removed metrics still present: {', '.join(removed)}")
    return failures


def goal_findings(report: dict[str, Any], baseline: dict[str, Any]) -> list[str]:
    goals = baseline["goals"] | baseline.get("scenarioGoals", {}).get(report["scenario"], {})
    checks = (
        ("averageFPS", "minimumAverageFPS", "average FPS", "below", True),
        ("onePercentLowFPS", "minimumOnePercentLowFPS", "1% low", "below", True),
        ("severeStallCount", "maximumSevereStallCount", "severe stalls", "above", False),
        ("missedDeadlineCount", "maximumMissedDeadlineCount", "missed deadlines", "above", False),
        ("maxFrameMs", "maximumFrameMs", "max frame ms", "above", False),
    )
    findings = []
    for metric, goal, label, direction, minimum in checks:
        if goal not in goals:
            continue
        limit = float(goals[goal])
        if not math.isfinite(limit) or limit < 0:
            raise SystemExit(f"baseline {goal} must be finite and non-negative")
        value = float(report[metric])
        outside_goal = value < limit if minimum else value > limit
        if outside_goal:
            findings.append(f"{report['scenario']} repetition {report['iteration']}: {label} {value:.2f} {direction} {limit:.2f}")
    return findings
