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
GOAL_CHECKS = (
    ("averageFPS", "minimumAverageFPS", "average FPS", "below", True),
    ("onePercentLowFPS", "minimumOnePercentLowFPS", "1% low", "below", True),
    ("severeStallCount", "maximumSevereStallCount", "severe stalls", "above", False),
    ("missedDeadlineCount", "maximumMissedDeadlineCount", "missed deadlines", "above", False),
    ("maxFrameMs", "maximumFrameMs", "max frame ms", "above", False),
)
REMOVED_FIELDS = ("p999FrameMs", "pointOnePercentLowFPS")
REQUIRED_SCHEMA_VERSION = 6


def finite_number(report: dict[str, Any], key: str) -> float:
    value = report.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{key} is missing or non-numeric")
    try:
        result = float(value)
    except OverflowError as error:
        raise ValueError(f"{key} is not finite") from error
    if not math.isfinite(result):
        raise ValueError(f"{key} is not finite")
    return result


def validate_report_domains(report: dict[str, Any]) -> list[str]:
    scenario = report.get("scenario")
    failures: list[str] = []
    for metric in METRICS:
        try:
            numeric = finite_number(report, metric)
        except ValueError as error:
            failures.append(f"{scenario}: {error}")
            continue
        if metric in COUNT_METRICS and (not numeric.is_integer() or numeric < 0):
            failures.append(f"{scenario}: {metric} must be a non-negative integer")
        elif metric in NON_NEGATIVE_METRICS and numeric < 0:
            failures.append(f"{scenario}: {metric} must be non-negative")
        elif metric == "missedDeadlineRatio" and not 0 <= numeric <= 1:
            failures.append(f"{scenario}: missedDeadlineRatio must be between 0 and 1")
    return failures


def load_results_reports(payload: dict[str, Any]) -> list[dict[str, Any]]:
    """Extract the reports array from a collected results payload."""
    reports = payload.get("reports") if isinstance(payload, dict) else None
    if not isinstance(reports, list):
        raise SystemExit("results payload must contain a reports array")
    return reports


def load_baseline(baseline: dict[str, Any]) -> tuple[list[str], str]:
    if not isinstance(baseline, dict):
        raise SystemExit("baseline must be an object")
    scenarios = baseline.get("scenarios")
    if not isinstance(scenarios, list) or not scenarios or any(
        not isinstance(value, str) or not value for value in scenarios
    ):
        raise SystemExit("baseline must contain a non-empty scenarios array")
    if len(set(scenarios)) != len(scenarios):
        raise SystemExit("baseline scenarios must be unique")
    try:
        goals = baseline["goals"]
        overrides = baseline.get("scenarioGoals", {})
        if not isinstance(goals, dict) or not isinstance(overrides, dict):
            raise ValueError("goals and scenarioGoals must be objects")
        for _, goal, *_ in GOAL_CHECKS[:3]:
            finite_number(goals, goal)
        for settings in (goals, *overrides.values()):
            if not isinstance(settings, dict):
                raise ValueError("scenario goals must be objects")
            unknown = settings.keys() - {goal for _, goal, *_ in GOAL_CHECKS}
            if unknown:
                raise ValueError(f"unknown performance goals: {sorted(unknown)}")
            for _, goal, *_ in GOAL_CHECKS:
                if goal in settings and finite_number(settings, goal) < 0:
                    raise ValueError(f"{goal} must be non-negative")
        if finite_number({"refreshTargetHz": baseline.get("refreshTargetHz", 60)}, "refreshTargetHz") <= 0:
            raise ValueError("refreshTargetHz must be positive")
        schema = baseline.get("minimumReportSchema", 5)
        if type(schema) is not int or schema < 1:
            raise ValueError("minimumReportSchema must be a positive integer")
    except (KeyError, ValueError) as error:
        raise SystemExit(f"baseline goals are invalid: {error}") from error
    mode = baseline.get("mode", "observe")
    if mode not in ("observe", "enforce"):
        raise SystemExit(f"baseline mode must be 'observe' or 'enforce', found {mode!r}")
    return scenarios, mode


def group_reports_by_scenario(
    reports: list, scenarios: list[str], baseline: dict[str, Any], *, repetitions: int = 1,
) -> tuple[dict[str, list[dict[str, Any]]], list[str]]:
    """Validate reports and require each maintained scenario's complete iteration sequence."""
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
        invalid = validate_report(raw_report, baseline)
        failures.extend(invalid)
        if not invalid:
            grouped[scenario].append(raw_report)
    expected = list(range(1, repetitions + 1))
    for scenario, records in grouped.items():
        records.sort(key=lambda report: report["iteration"])
        actual = [report["iteration"] for report in records]
        if actual != expected:
            failures.append(f"{scenario}: expected iterations 1..{repetitions}, found {actual}")
    return grouped, failures


def validate_report(report: dict[str, Any], baseline: dict[str, Any] | None = None) -> list[str]:
    scenario = report.get("scenario")
    failures = validate_report_domains(report)
    version = report.get("schemaVersion")
    if type(version) is not int or version not in (5, REQUIRED_SCHEMA_VERSION):
        failures.append(f"{scenario}: expected frame report schema {REQUIRED_SCHEMA_VERSION}, found {report.get('schemaVersion')!r}")
    iteration = report.get("iteration")
    if isinstance(iteration, bool) or not isinstance(iteration, int) or iteration < 1:
        failures.append(f"{scenario}: iteration must be a positive integer")
    if version == REQUIRED_SCHEMA_VERSION:
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
    if baseline and (not isinstance(version, int) or isinstance(version, bool) or version < baseline.get("minimumReportSchema", 5)):
        failures.append(f"{scenario}: legacy report cannot establish interaction coverage")
    removed = [key for key in REMOVED_FIELDS if key in report]
    if removed:
        failures.append(f"{scenario}: removed metrics still present: {', '.join(removed)}")
    return failures


def goal_findings(report: dict[str, Any], baseline: dict[str, Any]) -> list[str]:
    goals = baseline["goals"] | baseline.get("scenarioGoals", {}).get(report["scenario"], {})
    findings = []
    for metric, goal, label, direction, minimum in GOAL_CHECKS:
        if goal not in goals:
            continue
        limit = float(goals[goal])
        value = float(report[metric])
        outside_goal = value < limit if minimum else value > limit
        if outside_goal:
            findings.append(f"{report['scenario']} repetition {report['iteration']}: {label} {value:.2f} {direction} {limit:.2f}")
    return findings
