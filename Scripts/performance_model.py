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
REQUIRED_SCHEMA_VERSION = 4


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
    for key in NON_NEGATIVE_METRICS:
        if values[key] < 0:
            failures.append(f"{scenario}: {key} must be non-negative")
    for key in COUNT_METRICS:
        if not values[key].is_integer() or values[key] < 0:
            failures.append(f"{scenario}: {key} must be a non-negative integer")
    ratio = values["missedDeadlineRatio"]
    if ratio < 0 or ratio > 1:
        failures.append(f"{scenario}: missedDeadlineRatio must be between 0 and 1")
    return failures


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
    return scenarios, str(baseline.get("mode", "observe")), minimum_average, minimum_low, maximum_severe
