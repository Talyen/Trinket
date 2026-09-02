#!/usr/bin/env python3
"""Xcresult/log parsers for failure diagnostics (extracted from failure_diagnostics.py)."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from typing import Any, Iterable

sys.path.insert(0, str(Path(__file__).resolve().parent))

try:
    from diagnostic_model import (
        CLASSIFICATION_PRECEDENCE,
        CLASSIFICATIONS,
        GENERIC_MESSAGES,
        MAX_ISSUES,
        DiagnosticIssue,
        IssueObservation,
        identifier_aliases,
    )
except ModuleNotFoundError:
    from Scripts.diagnostic_model import (
        CLASSIFICATION_PRECEDENCE,
        CLASSIFICATIONS,
        GENERIC_MESSAGES,
        MAX_ISSUES,
        DiagnosticIssue,
        IssueObservation,
        identifier_aliases,
    )

# Each detail fetch is a separate xcresulttool process; summary/test-node parsing already
# yields file, line, and message for most failures. Cap enrichment to bound bad-run latency.
MAX_TEST_DETAIL_FETCHES = 5
ACCESSIBILITY_SNAPSHOT_MARKER = "Accessibility snapshot:"
_DISPLAY_PATH_CACHE: dict[str, str] = {}


def _load_infrastructure_pattern() -> str:
    """Read the canonical infrastructure vocabulary shared with the bash matchers."""
    config = Path(__file__).resolve().parent / "config" / "infrastructure-patterns.env"
    try:
        for line in config.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if stripped.startswith("TRINKET_INFRASTRUCTURE_FAILURE_PATTERN="):
                value = stripped.split("=", 1)[1].strip().strip("'\"")
                if value:
                    return value
    except OSError:
        pass
    # Minimal fallback keeps simulator classification working if the config file
    # is missing; the bash retry matcher fails closed on its own source error.
    return r"unable to boot|coresimulatorservice|coresimulator (?:service|error|failure|failed|unavailable)"


INFRASTRUCTURE_FAILURE_PATTERN = _load_infrastructure_pattern()


def _value(value: Any, default: Any = "") -> Any:
    if isinstance(value, dict) and "_value" in value:
        return value.get("_value", default)
    return default if value is None else value


def _values(value: Any) -> list[Any]:
    if isinstance(value, dict) and "_values" in value:
        value = value.get("_values")
    return value if isinstance(value, list) else []


def _text(value: Any, default: str = "") -> str:
    result = _value(value, default)
    return str(result).strip() if result is not None else default


def _normalise_path(path: str) -> str:
    if not path:
        return ""
    try:
        candidate = Path(path).expanduser()
        if not candidate.is_absolute():
            candidate = Path.cwd() / candidate
        return str(candidate.resolve())
    except OSError:
        return path


def _display_path(path: str) -> str:
    cached = _DISPLAY_PATH_CACHE.get(path)
    if cached is not None:
        return cached
    if not path:
        _DISPLAY_PATH_CACHE[path] = ""
        return ""
    candidate = Path(path).expanduser()
    if not candidate.is_absolute() and not candidate.exists():
        matches: list[Path] = []
        for root, directories, files in os.walk(Path.cwd()):
            directories[:] = [
                name
                for name in directories
                if name not in {".git", ".DerivedData", "build", ".tools", "__pycache__"}
            ]
            if candidate.name in files:
                matches.append(Path(root) / candidate.name)
                if len(matches) > 1:
                    break
        if len(matches) == 1:
            candidate = matches[0]
    absolute = _normalise_path(str(candidate))
    try:
        relative = os.path.relpath(absolute, Path.cwd())
        display = relative if not relative.startswith("..") else absolute
    except OSError:
        display = absolute
    _DISPLAY_PATH_CACHE[path] = display
    return display


def _issue_priority(issue: DiagnosticIssue) -> tuple[int, int, int, int]:
    """Rank actionable source failures before generic/tooling noise."""
    kind_rank = (
        CLASSIFICATION_PRECEDENCE.index(issue.kind)
        if issue.kind in CLASSIFICATION_PRECEDENCE
        else len(CLASSIFICATION_PRECEDENCE)
    )
    return (
        0 if issue.file else 1,
        0 if not issue.generic else 1,
        kind_rank,
        0 if issue.test else 1,
    )


def _prioritize_issues(issues: list[DiagnosticIssue]) -> list[DiagnosticIssue]:
    """Keep the structured report bounded while preserving likely root causes."""
    return sorted(issues, key=_issue_priority)[:MAX_ISSUES]


_CONFIGURATION_PATTERNS = (
    r"scheme .{0,80}not found",
    r"workspace .{0,40}does not contain",
    r"test plan",
    r"invalid destination",
    r"unable to find a destination",
    r"destination .* unavailable",
    r"requires a provisioning profile",
    r"requires a development team",
    r"no such module",
    r"code signing",
)

_TOOLING_PATTERNS = (
    r"command not found",
    r"unable to find utility",
    r"xcode-select",
    r"developer directory",
    r"toolchain",
    r"swiftlint",
)


def _classify_text(text: str, default: str) -> str:
    lowered = text.lower()
    # Canonical vocabulary shared with the bash retry/rerun matchers; see
    # Scripts/config/infrastructure-patterns.env.
    if re.search(INFRASTRUCTURE_FAILURE_PATTERN, lowered):
        return "simulator-infrastructure"
    if re.search(r"xctassert|xctfail|assertion failed|expectation failed", lowered):
        return "test-failure"
    if any(re.search(pattern, lowered) for pattern in _CONFIGURATION_PATTERNS):
        return "configuration"
    if any(re.search(pattern, lowered) for pattern in _TOOLING_PATTERNS):
        return "tooling"
    return default if default in CLASSIFICATIONS else "unknown"


def _split_accessibility_snapshot(message: str) -> tuple[str, str]:
    if ACCESSIBILITY_SNAPSHOT_MARKER not in message:
        return message.strip(), ""
    failure, snapshot = message.split(ACCESSIBILITY_SNAPSHOT_MARKER, 1)
    detail_lines = []
    for line in snapshot.strip().splitlines():
        stripped = line.strip()
        if stripped.startswith("AX: "):
            stripped = stripped[4:]
        if stripped:
            detail_lines.append(stripped)
    return failure.strip(), "\n".join(detail_lines)


def _extract_location(value: Any) -> tuple[str, int | None]:
    if not isinstance(value, dict):
        return "", None
    file_name = _text(value.get("fileName"))
    line = value.get("lineNumber")
    if isinstance(line, dict):
        line = _value(line)
    try:
        line_number = int(line) if line not in (None, "") else None
    except (TypeError, ValueError):
        line_number = None
    if file_name:
        return _display_path(file_name), line_number

    source_url = _text(value.get("sourceURL")) or _text(value.get("documentLocation"))
    if not source_url and isinstance(value.get("documentLocationInCreatingWorkspace"), dict):
        source_url = _text(value["documentLocationInCreatingWorkspace"].get("url"))
    if source_url.startswith("file://"):
        source_url = source_url[7:]
    if "#" in source_url:
        source_url, fragment = source_url.split("#", 1)
        match = re.search(r"(?P<key>StartingLineNumber|Starting|Line|line)[=:](?P<line>\d+)", fragment)
        if match and line_number is None:
            line_number = int(match.group("line"))
            if match.group("key") == "StartingLineNumber":
                line_number += 1
    return (_display_path(source_url) if source_url else ""), line_number


def parse_summary(summary: dict[str, Any]) -> list[IssueObservation]:
    failures = summary.get("testFailures", [])
    if not isinstance(failures, list):
        failures = _values(failures)
    observations: list[IssueObservation] = []
    for failure in failures:
        if not isinstance(failure, dict):
            continue
        test = _text(failure.get("testIdentifierString")) or _text(failure.get("testName"))
        test_url = _text(failure.get("testIdentifierURL"))
        message = _text(failure.get("failureText")) or _text(failure.get("message"))
        message, details = _split_accessibility_snapshot(message)
        file, line = _extract_location(failure)
        observations.append(
            IssueObservation(
                kind=_classify_text(message, "test-failure"),
                title=_text(failure.get("targetName")) or test or "Test failure",
                message=message,
                test=test,
                test_aliases=identifier_aliases(test, test_url),
                file=file,
                line=line,
                details=details,
            )
        )
    return observations


def _walk_test_nodes(node: Any) -> Iterable[dict[str, Any]]:
    if isinstance(node, dict):
        yield node
        for child in node.get("children", []) or []:
            yield from _walk_test_nodes(child)
        for child in _values(node.get("subtests")):
            yield from _walk_test_nodes(child)
    elif isinstance(node, list):
        for child in node:
            yield from _walk_test_nodes(child)


def parse_test_nodes(tests: dict[str, Any]) -> tuple[list[IssueObservation], list[str]]:
    observations: list[IssueObservation] = []
    failed_ids: list[str] = []
    for node in _walk_test_nodes(tests.get("testNodes", [])):
        if _text(node.get("result")).lower() != "failed":
            continue
        node_type = _text(node.get("nodeType")).lower()
        if node_type and "case" not in node_type:
            continue
        test = _text(node.get("nodeIdentifier")) or _text(node.get("name"))
        test_url = _text(node.get("nodeIdentifierURL"))
        if test_url:
            failed_ids.append(test_url)
        aliases = identifier_aliases(test, test_url)
        observations.append(
            IssueObservation(
                kind="test-failure",
                title=test or "Test failure",
                message="Test reported Failed",
                test=test,
                test_aliases=aliases,
                generic=True,
            )
        )
        for child in _walk_test_nodes(node.get("children", [])):
            if "failure" not in _text(child.get("nodeType")).lower():
                continue
            match = re.search(
                r"(?P<file>[^\n:]+\.(?:swift|m|mm|c|cc|cpp|h)):(?P<line>\d+):\s*(?P<message>.+)$",
                _text(child.get("name")),
            )
            if match:
                observations.append(
                    IssueObservation(
                        kind="test-failure",
                        title=test or "Test failure",
                        message=match.group("message"),
                        test=test,
                        test_aliases=aliases,
                        file=_display_path(match.group("file")),
                        line=int(match.group("line")),
                    )
                )
    return observations, list(dict.fromkeys(failed_ids))


def _collect_strings(node: Any, output: list[str]) -> None:
    if isinstance(node, dict):
        for key, value in node.items():
            if key in {"name", "details", "message", "failureText"} and isinstance(value, str):
                output.append(value)
            else:
                _collect_strings(value, output)
    elif isinstance(node, list):
        for value in node:
            _collect_strings(value, output)


def parse_test_detail(detail: dict[str, Any], test_id: str) -> IssueObservation:
    test = _text(detail.get("testIdentifier")) or test_id
    test_url = _text(detail.get("testIdentifierURL")) or test_id
    title = _text(detail.get("testName")) or test
    values: list[str] = []
    _collect_strings(detail.get("testRuns", []), values)
    failures = [value for value in values if value and ("failed" in value.lower() or "expectation" in value.lower())]
    message = next((value for value in failures if "expectation" in value.lower()), "Test reported Failed")
    message, accessibility_details = _split_accessibility_snapshot(message)
    file = ""
    line: int | None = None
    match = re.search(
        r"(?P<file>[^\n:]+\.(?:swift|m|mm|c|cc|cpp|h)):(?P<line>\d+):\s*(?P<message>.+)$",
        message,
    )
    if match:
        file = _display_path(match.group("file"))
        line = int(match.group("line"))
        message = match.group("message").strip()
    return IssueObservation(
        kind=_classify_text(message, "test-failure"),
        title=title,
        message=message,
        test=test,
        test_aliases=identifier_aliases(test, test_url, test_id),
        file=file,
        line=line,
        details=accessibility_details or "\n".join(dict.fromkeys(values)),
        generic=message in GENERIC_MESSAGES,
    )


def parse_build_results(build: dict[str, Any]) -> list[IssueObservation]:
    errors = _values(build.get("errors"))
    if not errors and isinstance(build.get("errors"), list):
        errors = build["errors"]
    if not errors:
        errors = _values(build.get("issues"))
    if not errors and isinstance(build.get("issues"), list):
        errors = build["issues"]
    observations: list[IssueObservation] = []
    for error in errors:
        if not isinstance(error, dict):
            continue
        message = _text(error.get("message")) or _text(error.get("description"))
        file, line = _extract_location(error)
        observations.append(
            IssueObservation(
                kind=_classify_text(message, "build-failure"),
                title=_text(error.get("targetName")) or _text(error.get("issueType")) or "Build failure",
                message=message,
                file=file,
                line=line,
            )
        )
    status = _text(build.get("status")).lower()
    try:
        error_count = int(build.get("errorCount", 0) or 0)
    except (TypeError, ValueError):
        error_count = 0
    if (status in {"failed", "failure"} or error_count > 0) and not errors:
        observations.append(IssueObservation("build-failure", "Build failure", "Build reported Failed"))
    return observations


LOG_PATTERNS: tuple[tuple[str, str, str], ...] = (
    (r"(?:undefined symbols for architecture|symbol\(s\) not found|duplicate symbol|linker command failed|ld: .*error|framework .* not found|library .* not found)", "build-failure", "Linker failure"),
    # Canonical simulator vocabulary first so a crash/timeout line that also
    # names the simulator classifies as infrastructure, not test failure.
    (INFRASTRUCTURE_FAILURE_PATTERN, "simulator-infrastructure", "Simulator infrastructure"),
    (r"(?:XCTAssert\w*\s*failed|XCTFail|XCTUnwrap.*failed|assertion failed|expectation failed)", "test-failure", "XCTest assertion failure"),
    (r"(?:test (?:runner|process) (?:crashed|crash|exited)|test .*terminated unexpectedly|testing failed|failed to (?:build|test)|terminated due to signal|killed by signal|(?:test .*|^|\s)timed? out|timeout|hang detected|(?:failed to launch test|test .*failed to launch)|test execution interrupted|exc_crash|abort trap|signal [0-9]+)", "test-failure", "Test process failure"),
    (r"(?:scheme .{0,80}not found|workspace .{0,40}does not contain|no test plan|invalid destination|unable to find a destination|destination .* unavailable|requires a provisioning profile|code signing|requires a development team|no such module)", "configuration", "Configuration failure"),
    (r"(?:command not found|unable to find utility|xcode-select[^\n]*error|developer directory[^\n]*(?:invalid|missing|not found)|toolchain[^\n]*(?:not found|invalid|not configured)|swiftlint[^\n]*(?:error|not found|unavailable))", "tooling", "Tooling failure"),
    (r"xcodebuild: error", "unknown", "Xcode invocation"),
)


def parse_log(log_path: Path, exit_code: int) -> list[IssueObservation]:
    try:
        stream = log_path.open("r", encoding="utf-8", errors="replace")
    except OSError:
        return []
    observations: list[IssueObservation] = []
    diagnostic = re.compile(r"^(?P<file>[^\n:]+(?::[^\n:]+)*):(?P<line>\d+)(?::\d+)?:\s*(?:fatal )?error:\s*(?P<message>.+)$", re.I)
    xctest_failure = re.compile(
        r"^-\[(?P<test>[^\]]+)\]\s*:\s*failed\s*-\s*(?P<message>.*)$",
        re.I,
    )
    try:
        lines = iter(stream)
        pending_line: str | None = None
        while True:
            raw_line = pending_line if pending_line is not None else next(lines, None)
            pending_line = None
            if raw_line is None:
                break
            line_text = raw_line.strip()
            match = diagnostic.search(line_text)
            if match:
                message = match.group("message").strip()
                test_match = xctest_failure.match(message)
                if test_match:
                    failure_message, details = _split_accessibility_snapshot(test_match.group("message"))
                    next_line = next(lines, "")
                    if next_line.strip() == ACCESSIBILITY_SNAPSHOT_MARKER:
                        snapshot_lines = []
                        for continuation in lines:
                            stripped = continuation.strip()
                            if not stripped.startswith("AX: "):
                                pending_line = continuation
                                break
                            snapshot_lines.append(stripped[4:])
                        details = "\n".join(snapshot_lines)
                    elif next_line:
                        pending_line = next_line
                    test = test_match.group("test").strip()
                    observation = IssueObservation(
                        "test-failure",
                        test or "XCTest failure",
                        failure_message,
                        test=test,
                        file=_display_path(match.group("file")),
                        line=int(match.group("line")),
                        details=details,
                    )
                else:
                    observation = IssueObservation(
                        _classify_text(message, "build-failure"),
                        "Build diagnostic",
                        message,
                        file=_display_path(match.group("file")),
                        line=int(match.group("line")),
                    )
            else:
                observation = next(
                    (
                        IssueObservation(_classify_text(line_text, kind), title, line_text)
                        for pattern, kind, title in LOG_PATTERNS
                        if re.search(pattern, line_text, re.I)
                    ),
                    None,
                )
            if observation is not None:
                identity = (
                    observation.kind,
                    observation.title,
                    observation.message,
                    observation.file,
                    observation.line,
                )
                if any(
                    (
                        existing.kind,
                        existing.title,
                        existing.message,
                        existing.file,
                        existing.line,
                    ) == identity
                    for existing in observations
                ):
                    continue
                if len(observations) < MAX_ISSUES:
                    observations.append(observation)
                else:
                    observations[MAX_ISSUES - 1] = observation
    finally:
        stream.close()
    if not observations and exit_code != 0:
        observations.append(IssueObservation("unknown", "Xcode invocation", f"Xcode exited with code {exit_code}"))
    return observations
