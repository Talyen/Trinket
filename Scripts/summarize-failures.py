#!/usr/bin/env python3
"""Produce a small, machine-readable report for a failed Xcode invocation.

The reporter deliberately uses the public ``xcresulttool`` report APIs rather
than walking the private result-bundle object graph.  A result bundle is the
authoritative source for tests and build diagnostics; the xcodebuild log is
used only when the structured report is unavailable or contains no failures.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


CLASSIFICATIONS = (
    "test-failure",
    "build-failure",
    "simulator-infrastructure",
    "configuration",
    "tooling",
    "unknown",
)
CLASSIFICATION_PRECEDENCE = (
    "test-failure",
    "build-failure",
    "configuration",
    "tooling",
    "simulator-infrastructure",
    "unknown",
)
MAX_ISSUES = 20
MAX_LINES = 120


def _value(value: Any, default: Any = "") -> Any:
    """Read either a new xcresult JSON value or a legacy object value."""

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
    if not path:
        return ""
    candidate = Path(path).expanduser()
    if not candidate.is_absolute() and not candidate.exists():
        # XCTest frequently reports only ``SomeTests.swift``.  Resolve that
        # basename to a repository-relative path when it is unambiguous.
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
        return relative if not relative.startswith("..") else absolute
    except OSError:
        return absolute


def _output_stem(value: str) -> Path:
    stem = Path(value).expanduser()
    # Accepting a suffix here makes integration forgiving when a caller uses
    # --output-prefix report.json while retaining the documented report.json
    # output for a prefix of ``report``.
    if stem.suffix in {".json", ".md", ".annotations"}:
        stem = stem.with_suffix("")
    return stem


def run_xcresulttool(result_bundle: Path, arguments: list[str]) -> tuple[Any | None, str | None]:
    """Run a supported xcresulttool report API and decode its JSON output."""

    command = ["xcrun", "xcresulttool", *arguments, "--path", str(result_bundle), "--compact"]
    try:
        completed = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError as error:
        return None, f"could not execute {' '.join(command[:3])}: {error}"
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "command failed").strip()
        return None, f"{' '.join(command)} exited {completed.returncode}: {detail[:500]}"
    try:
        return json.loads(completed.stdout), None
    except json.JSONDecodeError as error:
        return None, f"{' '.join(command)} returned invalid JSON: {error}"


def _classify_text(text: str, default: str) -> str:
    lowered = text.lower()
    if any(
        token in lowered
        for token in (
            "simulator",
            "simctl",
            "unable to boot",
            "could not boot",
            "device is not available",
            "no devices are booted",
            "launch session",
            "connection to the service",
            "launchd",
            "timed out while launching",
            "failed to launch",
            "background assertion",
            "failed to get background assertion",
        )
    ):
        return "simulator-infrastructure"
    if any(
        token in lowered
        for token in (
            "scheme",
            "test plan",
            "destination",
            "configuration",
            "workspace does not contain",
            "requires a development team",
            "no such module",
            "signing",
        )
    ):
        return "configuration"
    if any(
        token in lowered
        for token in (
            "command not found",
            "xcresulttool",
            "xcodebuild: error",
            "unable to find utility",
            "developer directory",
            "toolchain",
            "swiftlint",
        )
    ):
        return "tooling"
    return default if default in CLASSIFICATIONS else "unknown"


def _extract_location(value: Any) -> tuple[str, int | None]:
    """Extract a source path and one-based line from structured issue data."""

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


def _new_issue(
    *,
    kind: str,
    title: str,
    message: str,
    test: str = "",
    file: str = "",
    line: int | None = None,
    details: str = "",
) -> dict[str, Any]:
    message = re.sub(r"\s+", " ", message.strip()) or "No failure details"
    details = details.strip()
    identity = "\x1f".join((kind, title, test, file, str(line or ""), message))
    issue_id = hashlib.sha1(identity.encode("utf-8")).hexdigest()[:16]
    return {
        "id": issue_id,
        "kind": kind if kind in CLASSIFICATIONS else "unknown",
        "title": title or "Xcode failure",
        "message": message,
        "file": file,
        "line": line,
        "test": test,
        "details": details,
        "attachments": [],
    }


def _append_issue(issues: list[dict[str, Any]], issue: dict[str, Any]) -> None:
    """Deduplicate by stable id while preserving the richest test diagnostic.

    ``summary`` names the assertion, ``tests`` names the test node, and
    ``test-details`` provides expression details.  They are three views of
    one failure, not three independent issues, so test failures coalesce by
    test identifier while retaining the most useful message/details.
    """

    for existing in issues:
        if existing["id"] == issue["id"]:
            return
        if existing.get("test") and existing.get("test") == issue.get("test") and existing.get("kind") != "build-failure" and issue.get("kind") != "build-failure":
            generic = {"Test reported Failed", "No failure details"}
            if existing.get("kind") == "test-failure" and issue.get("kind") != "test-failure":
                existing["kind"] = issue["kind"]
            if existing.get("message") in generic and issue.get("message") not in generic:
                existing["message"] = issue["message"]
            if len(issue.get("details", "")) > len(existing.get("details", "")):
                existing["details"] = issue["details"]
            if not existing.get("file") and issue.get("file"):
                existing["file"] = issue["file"]
                existing["line"] = issue.get("line")
            if not existing.get("title") or existing.get("title") == "Test failure":
                existing["title"] = issue.get("title", existing["title"])
            existing["id"] = hashlib.sha1(
                "\x1f".join(
                    (
                        existing.get("kind", ""),
                        existing.get("title", ""),
                        existing.get("test", ""),
                        existing.get("file", ""),
                        str(existing.get("line") or ""),
                        existing.get("message", ""),
                    )
                ).encode("utf-8")
            ).hexdigest()[:16]
            return
    issues.append(issue)


def _summary_failure_issues(summary: dict[str, Any], issues: list[dict[str, Any]]) -> None:
    failures = summary.get("testFailures", [])
    if not isinstance(failures, list):
        failures = _values(failures)
    for failure in failures:
        if not isinstance(failure, dict):
            continue
        test = _text(failure.get("testIdentifierString")) or _text(failure.get("testName"))
        message = _text(failure.get("failureText")) or _text(failure.get("message"))
        title = _text(failure.get("targetName")) or test or "Test failure"
        file, line = _extract_location(failure)
        kind = _classify_text(message, "test-failure")
        _append_issue(
            issues,
            _new_issue(kind=kind, title=title, message=message, test=test, file=file, line=line),
        )


def _walk_test_nodes(node: Any) -> Iterable[dict[str, Any]]:
    if isinstance(node, dict):
        yield node
        for child in node.get("children", []) or []:
            yield from _walk_test_nodes(child)
        # Older result-bundle JSON uses _values/subtests instead of children.
        for child in _values(node.get("subtests")):
            yield from _walk_test_nodes(child)
    elif isinstance(node, list):
        for child in node:
            yield from _walk_test_nodes(child)


def _test_nodes_and_ids(tests: dict[str, Any], issues: list[dict[str, Any]]) -> list[str]:
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
        title = test or "Test failure"
        _append_issue(
            issues,
            _new_issue(kind="test-failure", title=title, message="Test reported Failed", test=test),
        )
        # The tests endpoint may carry a richer Failure Message child than
        # the summary endpoint.  Preserve its source line before fetching
        # test-details (which often omits that location).
        for child in _walk_test_nodes(node.get("children", [])):
            if "failure" not in _text(child.get("nodeType")).lower():
                continue
            failure_name = _text(child.get("name"))
            match = re.search(
                r"(?P<file>[^\n:]+\.(?:swift|m|mm|c|cc|cpp|h)):(?P<line>\d+):\s*(?P<message>.+)$",
                failure_name,
            )
            if not match:
                continue
            _append_issue(
                issues,
                _new_issue(
                    kind="test-failure",
                    title=title,
                    message=match.group("message"),
                    test=test,
                    file=_display_path(match.group("file")),
                    line=int(match.group("line")),
                ),
            )
    return list(dict.fromkeys(failed_ids))


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


def _add_test_detail(detail: dict[str, Any], test_id: str, issues: list[dict[str, Any]]) -> None:
    test = _text(detail.get("testIdentifier")) or test_id
    title = _text(detail.get("testName")) or test
    values: list[str] = []
    _collect_strings(detail.get("testRuns", []), values)
    failures = [value for value in values if value and ("failed" in value.lower() or "expectation" in value.lower())]
    message = next((value for value in failures if "expectation" in value.lower()), "Test reported Failed")
    # Xcode's failure node commonly embeds the source location in its name,
    # e.g. ``SmokeHomesteadTests.swift:20: failed - element not found``.
    # This is the only source location available in the public test-details
    # response for many Swift Testing/XCTest failures.
    file = ""
    line: int | None = None
    location_match = re.search(r"(?P<file>[^\n:]+\.(?:swift|m|mm|c|cc|cpp|h)):(?P<line>\d+):\s*(?P<message>.+)$", message)
    if location_match:
        file = _display_path(location_match.group("file"))
        line = int(location_match.group("line"))
        message = location_match.group("message").strip()
    details = "\n".join(dict.fromkeys(values))
    kind = _classify_text(message, "test-failure")
    _append_issue(issues, _new_issue(kind=kind, title=title, message=message, test=test, file=file, line=line, details=details))


def _build_issues(build: dict[str, Any], issues: list[dict[str, Any]]) -> None:
    errors = _values(build.get("errors"))
    if not errors and isinstance(build.get("errors"), list):
        errors = build["errors"]
    if not errors:
        errors = _values(build.get("issues"))
    if not errors and isinstance(build.get("issues"), list):
        errors = build["issues"]
    for error in errors:
        if not isinstance(error, dict):
            continue
        message = _text(error.get("message")) or _text(error.get("description"))
        title = _text(error.get("targetName")) or _text(error.get("issueType")) or "Build failure"
        file, line = _extract_location(error)
        kind = _classify_text(message, "build-failure")
        _append_issue(issues, _new_issue(kind=kind, title=title, message=message, file=file, line=line))
    status = _text(build.get("status")).lower()
    try:
        error_count = int(build.get("errorCount", 0) or 0)
    except (TypeError, ValueError):
        error_count = 0
    if (status in {"failed", "failure"} or error_count > 0) and not errors:
        _append_issue(issues, _new_issue(kind="build-failure", title="Build failure", message="Build reported Failed"))


def _append_bounded_issue(issues: list[dict[str, Any]], issue: dict[str, Any], limit: int = MAX_ISSUES) -> None:
    """Retain a bounded first/last window while scanning an unbounded log."""

    before = len(issues)
    _append_issue(issues, issue)
    if len(issues) > before and len(issues) > limit:
        # Keep the first limit-1 matches and replace the final slot with the
        # newest match, ensuring a diagnostic at the end of a large log is
        # never hidden by an early wall of compiler output.
        del issues[limit - 1]


LOG_PATTERNS: tuple[tuple[str, str, str], ...] = (
    (
        r"(?:undefined symbols for architecture|symbol\(s\) not found|duplicate symbol|linker command failed|ld: .*error|framework .* not found|library .* not found)",
        "build-failure",
        "Linker failure",
    ),
    (
        r"(?:test (?:runner|process) (?:crashed|crash|exited)|test .*terminated unexpectedly|testing failed|failed to (?:build|test)|terminated due to signal|killed by signal|(?:test .*|^|\s)timed? out|timeout|hang detected|(?:failed to launch test|test .*failed to launch)|test execution interrupted|exc_crash|abort trap|signal [0-9]+)",
        "test-failure",
        "Test process failure",
    ),
    (
        r"(?:timed out while launching|failed to launch(?! test)|background assertion|failed to get background assertion)",
        "simulator-infrastructure",
        "Simulator infrastructure",
    ),
    (
        r"(?:scheme|test plan|no test plan|invalid destination|unable to find a destination|destination .* unavailable|requires a provisioning profile|code signing|workspace .* does not contain)",
        "configuration",
        "Configuration failure",
    ),
    (
        r"(?:command not found|unable to find utility|xcode-select|developer directory|toolchain|swiftlint|xcresulttool)",
        "tooling",
        "Tooling failure",
    ),
    (
        r"(?:xcodebuild: error|simulator|simctl|unable to boot|could not boot|coresimulator|launchd_sim|device .* unavailable|no devices are booted)",
        "unknown",
        "Xcode invocation",
    ),
)


def _log_issues(log_path: Path, exit_code: int) -> list[dict[str, Any]]:
    try:
        stream = log_path.open("r", encoding="utf-8", errors="replace")
    except OSError:
        return []
    issues: list[dict[str, Any]] = []
    # Swift and clang diagnostics include file:line:column: error:.  Keep the
    # regex conservative so paths containing colons do not create noise.
    diagnostic = re.compile(r"^(?P<file>[^\n:]+(?::[^\n:]+)*):(?P<line>\d+)(?::\d+)?:\s*(?:fatal )?error:\s*(?P<message>.+)$", re.I)
    try:
        for raw_line in stream:
            line_text = raw_line.strip()
            match = diagnostic.search(line_text)
            if match:
                message = match.group("message").strip()
                kind = _classify_text(message, "build-failure")
                _append_bounded_issue(
                    issues,
                    _new_issue(
                        kind=kind,
                        title="Build diagnostic",
                        message=message,
                        file=_display_path(match.group("file")),
                        line=int(match.group("line")),
                    ),
                )
                continue
            for pattern, default_kind, title in LOG_PATTERNS:
                if re.search(pattern, line_text, re.I):
                    kind = _classify_text(line_text, default_kind)
                    _append_bounded_issue(issues, _new_issue(kind=kind, title=title, message=line_text))
                    break
    finally:
        stream.close()
    if not issues and exit_code != 0:
        _append_bounded_issue(issues, _new_issue(kind="unknown", title="Xcode invocation", message=f"Xcode exited with code {exit_code}"))
    return issues


def export_failure_attachments(result_bundle: Path, output_dir: Path) -> tuple[bool, str | None]:
    output_dir.mkdir(parents=True, exist_ok=True)
    # xcresulttool writes a manifest and refuses to overwrite an existing one;
    # reports are intentionally rerunnable for the same output prefix.
    manifest = output_dir / "manifest.json"
    try:
        manifest.unlink(missing_ok=True)
    except OSError:
        pass
    command = [
        "xcrun",
        "xcresulttool",
        "export",
        "attachments",
        "--path",
        str(result_bundle),
        "--output-path",
        str(output_dir),
        "--only-failures",
    ]
    try:
        completed = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError as error:
        return False, str(error)
    if completed.returncode != 0:
        return False, (completed.stderr or completed.stdout or "attachment export failed").strip()[:500]
    return True, None


def _attachment_paths(directory: Path) -> list[str]:
    if not directory.exists():
        return []
    exported = [
        path
        for path in directory.rglob("*")
        if path.is_file() and path.name != "manifest.json"
    ]
    manifest = directory / "manifest.json"
    try:
        payload = json.loads(manifest.read_text(encoding="utf-8")) if manifest.exists() else []
    except (OSError, json.JSONDecodeError):
        payload = []
    manifest_attachments: list[dict[str, Any]] = []
    for test_entry in payload if isinstance(payload, list) else []:
        if isinstance(test_entry, dict):
            values = test_entry.get("attachments", [])
            if isinstance(values, list):
                manifest_attachments.extend(item for item in values if isinstance(item, dict))
    if manifest_attachments:
        associated_names = {
            _text(item.get("exportedFileName"))
            for item in manifest_attachments
            if item.get("isAssociatedWithFailure") is True
        }
        exported = [path for path in exported if path.name in associated_names]
    return sorted(_display_path(str(path)) for path in exported)


def _escape_annotation(value: str) -> str:
    return (
        str(value).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        .replace(":", "%3A").replace(",", "%2C")
    )


def _annotation(issue: dict[str, Any]) -> str:
    properties: list[str] = []
    if issue.get("file"):
        properties.append(f"file={_escape_annotation(issue['file'])}")
    if issue.get("line") is not None:
        properties.append(f"line={issue['line']}")
    properties.append(f"title={_escape_annotation(issue.get('title', 'Xcode failure'))}")
    fields = " " + ",".join(properties) if properties else ""
    return f"::error{fields}::{_escape_annotation(issue.get('message', 'Xcode failure'))}"


def _bounded_lines(lines: list[str], limit: int = MAX_LINES) -> list[str]:
    if len(lines) <= limit:
        return lines
    omitted = len(lines) - limit + 1
    return [*lines[: limit - 1], f"… {omitted} additional lines omitted by reporter"]


def render_markdown(report: dict[str, Any]) -> str:
    issues = report.get("issues", [])
    shown = issues[:MAX_ISSUES]
    lines = [
        f"# Failure diagnostics: {report.get('label') or 'Xcode'}",
        "",
        f"- Classification: `{report.get('classification', 'unknown')}`",
        f"- Exit code: `{report.get('exit_code', 0)}`",
        f"- Issues: `{len(issues)}` (showing at most {MAX_ISSUES})",
        "",
        "## Issues",
    ]
    if not shown:
        lines.append("No structured failure issues were reported.")
    for index, issue in enumerate(shown, 1):
        location = issue.get("file", "")
        if issue.get("line") is not None:
            location = f"{location}:{issue['line']}" if location else f"line {issue['line']}"
        suffix = f" — `{location}`" if location else ""
        test = f" ({issue['test']})" if issue.get("test") else ""
        lines.append(f"{index}. **{issue.get('title', 'Xcode failure')}**{test}{suffix}: {issue.get('message', '')}")
        for detail in str(issue.get("details", "")).splitlines()[:3]:
            lines.append(f"   - {detail}")
        for attachment in issue.get("attachments", []):
            lines.append(f"   - Attachment: `{attachment}`")
    if len(issues) > MAX_ISSUES:
        lines.append(f"\n_{len(issues) - MAX_ISSUES} additional issues are available in the JSON report._")
    if report.get("raw_log_path"):
        lines.extend(["", f"Raw log: `{report['raw_log_path']}`"])
    return "\n".join(_bounded_lines(lines)) + "\n"


def render_terminal(report: dict[str, Any]) -> list[str]:
    issues = report.get("issues", [])
    lines = [
        f"=== {report.get('label') or 'Xcode'} failure diagnostics ===",
        f"Classification: {report.get('classification', 'unknown')}",
        f"Exit code: {report.get('exit_code', 0)}",
        f"Issues: {len(issues)} (showing at most {MAX_ISSUES})",
    ]
    for index, issue in enumerate(issues[:MAX_ISSUES], 1):
        location = issue.get("file", "")
        if issue.get("line") is not None:
            location = f"{location}:{issue['line']}" if location else f"line {issue['line']}"
        location_suffix = f" [{location}]" if location else ""
        test_suffix = f" ({issue['test']})" if issue.get("test") else ""
        lines.append(f"{index}. {issue.get('kind', 'unknown')}: {issue.get('title', 'Xcode failure')}{test_suffix}{location_suffix}")
        lines.append(f"   {issue.get('message', '')}")
        if issue.get("attachments"):
            lines.append(f"   Attachments: {', '.join(str(item) for item in issue['attachments'])}")
    if len(issues) > MAX_ISSUES:
        lines.append(f"… {len(issues) - MAX_ISSUES} additional issues are available in the JSON report")
    if report.get("raw_log_path"):
        lines.append(f"Raw log: {report['raw_log_path']}")
    return _bounded_lines(lines)


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("legacy_result_bundle", nargs="?", help=argparse.SUPPRESS)
    parser.add_argument("--result-bundle", help="Path to the .xcresult bundle")
    parser.add_argument("--log", default="", help="Path to the xcodebuild log")
    parser.add_argument("--exit-code", type=int, default=1, help="Exit code from xcodebuild")
    parser.add_argument("--label", default="Xcode", help="Human-readable invocation label")
    parser.add_argument("--output-prefix", help="Prefix for JSON, Markdown, annotations, and attachments outputs")
    parser.add_argument("--defer-terminal-output", action="store_true", help="Write artifacts without normal terminal output")
    args = parser.parse_args(argv)
    if not args.result_bundle:
        args.result_bundle = args.legacy_result_bundle
    if not args.result_bundle:
        parser.error("--result-bundle is required")
    if not args.output_prefix:
        bundle = Path(args.result_bundle)
        args.output_prefix = str(bundle.parent / f"{bundle.stem}-diagnostics")
    return args


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    result_bundle = Path(args.result_bundle).expanduser()
    log_path = Path(args.log).expanduser() if args.log else None
    source: dict[str, Any] = {
        "build_results": False,
        "test_summary": False,
        "tests": False,
        "test_details": 0,
        "attachments": False,
        "errors": [],
    }
    issues: list[dict[str, Any]] = []
    failed_test_ids: list[str] = []

    if result_bundle.is_dir():
        build, error = run_xcresulttool(result_bundle, ["get", "build-results"])
        if build is not None:
            source["build_results"] = True
            _build_issues(build, issues)
        elif error:
            source["errors"].append(error)

        summary, error = run_xcresulttool(result_bundle, ["get", "test-results", "summary"])
        if summary is not None:
            source["test_summary"] = True
            _summary_failure_issues(summary, issues)
        elif error:
            source["errors"].append(error)

        tests, error = run_xcresulttool(result_bundle, ["get", "test-results", "tests"])
        if tests is not None:
            source["tests"] = True
            failed_test_ids = _test_nodes_and_ids(tests, issues)
        elif error:
            source["errors"].append(error)

        for test_id in failed_test_ids:
            detail, error = run_xcresulttool(result_bundle, ["get", "test-results", "test-details", "--test-id", test_id])
            if detail is not None:
                source["test_details"] += 1
                _add_test_detail(detail, test_id, issues)
            elif error:
                source["errors"].append(error)

    # Structured data wins.  A log is consulted only for a missing/empty
    # structured result, which avoids duplicate compiler/test diagnostics.
    if not issues and log_path:
        issues = _log_issues(log_path, args.exit_code)

    if not issues and args.exit_code != 0:
        issues = [_new_issue(kind="unknown", title="Xcode invocation", message=f"Xcode exited with code {args.exit_code}")]

    if issues:
        issue_kinds = {issue.get("kind") for issue in issues}
        classification = next(
            kind for kind in CLASSIFICATION_PRECEDENCE if kind in issue_kinds
        )
    else:
        classification = "unknown"

    output_stem = _output_stem(args.output_prefix)
    attachment_dir = Path(str(output_stem) + ".attachments")
    should_export = result_bundle.is_dir() and (bool(issues) or args.exit_code != 0)
    if should_export:
        exported, error = export_failure_attachments(result_bundle, attachment_dir)
        source["attachments"] = exported
        if error:
            source["errors"].append(f"attachment export: {error}")
        if exported:
            attachments = _attachment_paths(attachment_dir)
            if attachments:
                for issue in issues:
                    if issue.get("test"):
                        issue["attachments"] = attachments.copy()

    report: dict[str, Any] = {
        "schema_version": 1,
        "label": args.label,
        "result_bundle": _normalise_path(str(result_bundle)) if args.result_bundle else "",
        "log": _normalise_path(str(log_path)) if log_path else "",
        "exit_code": args.exit_code,
        "classification": classification,
        "issues": issues,
        "counts": {
            "total": len(issues),
            "by_classification": {kind: sum(issue.get("kind") == kind for issue in issues) for kind in CLASSIFICATIONS},
        },
        "structured_sources": source,
        "terminal": {"issue_limit": MAX_ISSUES, "line_limit": MAX_LINES},
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }
    # Raw log paths are intentionally withheld for diagnosed failures.  They
    # are useful only when no structured/log classification was possible.
    if classification == "unknown" and log_path and args.exit_code != 0:
        report["raw_log_path"] = _normalise_path(str(log_path))
    return report


def write_report(report: dict[str, Any], output_prefix: str) -> tuple[Path, Path, Path]:
    stem = _output_stem(output_prefix)
    json_path = Path(str(stem) + ".json")
    markdown_path = Path(str(stem) + ".md")
    annotations_path = Path(str(stem) + ".annotations")
    _write_text(json_path, json.dumps(report, indent=2, sort_keys=False) + "\n")
    _write_text(markdown_path, render_markdown(report))
    annotation_lines = [_annotation(issue) for issue in report.get("issues", [])[:MAX_ISSUES]]
    _write_text(annotations_path, "\n".join(annotation_lines) + ("\n" if annotation_lines else ""))
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        try:
            with Path(summary_path).open("a", encoding="utf-8") as stream:
                stream.write("\n" + render_markdown(report))
        except OSError as error:
            report.setdefault("structured_sources", {}).setdefault("errors", []).append(
                f"GitHub step summary: {error}"
            )
            # Keep the failure visible even when GitHub's summary file is not
            # writable, and persist the source error in the JSON artifact.
            print(f"summarize-failures.py: could not write GITHUB_STEP_SUMMARY: {error}", file=sys.stderr)
            _write_text(json_path, json.dumps(report, indent=2, sort_keys=False) + "\n")
    return json_path, markdown_path, annotations_path


def main(argv: list[str] | None = None) -> int:
    try:
        args = _parse_args(sys.argv[1:] if argv is None else argv)
        report = build_report(args)
        json_path, markdown_path, annotations_path = write_report(report, args.output_prefix)
        if not args.defer_terminal_output:
            print("\n".join(render_terminal(report)))
            if os.environ.get("GITHUB_ACTIONS", "").lower() == "true":
                print("\n".join(_annotation(issue) for issue in report.get("issues", [])[:MAX_ISSUES]))
            print(f"Report JSON: {json_path}", file=sys.stderr)
            print(f"Report Markdown: {markdown_path}", file=sys.stderr)
            print(f"Report annotations: {annotations_path}", file=sys.stderr)
        return 0
    except Exception as error:  # Reporter failures must never disappear in CI.
        print(f"summarize-failures.py: reporter execution failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
