#!/usr/bin/env python3
"""Collect, merge, and render bounded Xcode failure diagnostics."""

from __future__ import annotations

import argparse
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

try:
    import xcresult_diagnostics as xcresult
except ModuleNotFoundError:  # Imported as Scripts.failure_diagnostics in repository tests.
    from Scripts import xcresult_diagnostics as xcresult
try:
    from diagnostic_model import (
        CLASSIFICATIONS, CLASSIFICATION_PRECEDENCE, GENERIC_MESSAGES, MAX_ISSUES, MAX_LINES,
        DiagnosticIssue, DiagnosticReport, IssueAccumulator, IssueObservation, SourceStatus,
        identifier_aliases,
    )
    from diagnostic_rendering import render_annotation, render_markdown, render_terminal, write_report
except ModuleNotFoundError:
    from Scripts.diagnostic_model import (
        CLASSIFICATIONS, CLASSIFICATION_PRECEDENCE, GENERIC_MESSAGES, MAX_ISSUES, MAX_LINES,
        DiagnosticIssue, DiagnosticReport, IssueAccumulator, IssueObservation, SourceStatus,
        identifier_aliases,
    )
    from Scripts.diagnostic_rendering import render_annotation, render_markdown, render_terminal, write_report


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
    if not path:
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
        return relative if not relative.startswith("..") else absolute
    except OSError:
        return absolute


def _output_stem(value: str) -> Path:
    stem = Path(value).expanduser()
    if stem.suffix in {".json", ".md", ".annotations"}:
        stem = stem.with_suffix("")
    return stem


def _classify_text(text: str, default: str) -> str:
    lowered = text.lower()
    if any(
        token in lowered
        for token in (
            "simulator", "simctl", "unable to boot", "could not boot",
            "device is not available", "no devices are booted", "launch session",
            "connection to the service", "launchd", "timed out while launching",
            "failed to launch", "background assertion", "failed to get background assertion",
        )
    ):
        return "simulator-infrastructure"
    if any(
        token in lowered
        for token in (
            "scheme", "test plan", "destination", "configuration",
            "workspace does not contain", "requires a development team", "no such module", "signing",
        )
    ):
        return "configuration"
    if any(
        token in lowered
        for token in (
            "command not found", "xcresulttool", "xcodebuild: error",
            "unable to find utility", "developer directory", "toolchain", "swiftlint",
        )
    ):
        return "tooling"
    return default if default in CLASSIFICATIONS else "unknown"


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
        details="\n".join(dict.fromkeys(values)),
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
    (r"(?:test (?:runner|process) (?:crashed|crash|exited)|test .*terminated unexpectedly|testing failed|failed to (?:build|test)|terminated due to signal|killed by signal|(?:test .*|^|\s)timed? out|timeout|hang detected|(?:failed to launch test|test .*failed to launch)|test execution interrupted|exc_crash|abort trap|signal [0-9]+)", "test-failure", "Test process failure"),
    (r"(?:timed out while launching|failed to launch(?! test)|background assertion|failed to get background assertion)", "simulator-infrastructure", "Simulator infrastructure"),
    (r"(?:scheme|test plan|no test plan|invalid destination|unable to find a destination|destination .* unavailable|requires a provisioning profile|code signing|workspace .* does not contain)", "configuration", "Configuration failure"),
    (r"(?:command not found|unable to find utility|xcode-select|developer directory|toolchain|swiftlint|xcresulttool)", "tooling", "Tooling failure"),
    (r"(?:xcodebuild: error|simulator|simctl|unable to boot|could not boot|coresimulator|launchd_sim|device .* unavailable|no devices are booted)", "unknown", "Xcode invocation"),
)


def parse_log(log_path: Path, exit_code: int) -> list[IssueObservation]:
    try:
        stream = log_path.open("r", encoding="utf-8", errors="replace")
    except OSError:
        return []
    observations: list[IssueObservation] = []
    diagnostic = re.compile(r"^(?P<file>[^\n:]+(?::[^\n:]+)*):(?P<line>\d+)(?::\d+)?:\s*(?:fatal )?error:\s*(?P<message>.+)$", re.I)
    try:
        for raw_line in stream:
            line_text = raw_line.strip()
            match = diagnostic.search(line_text)
            if match:
                message = match.group("message").strip()
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


def _attachment_path(directory: Path, name: str) -> str:
    path = directory / name
    return _display_path(str(path)) if path.is_file() else ""


def assign_attachments(
    issues: list[DiagnosticIssue],
    directory: Path,
    records: list[xcresult.ExportedAttachment],
) -> list[str]:
    unmatched: list[str] = []
    for record in records:
        if not record.associated_with_failure:
            continue
        path = _attachment_path(directory, record.exported_file_name)
        if not path:
            continue
        aliases = identifier_aliases(record.test_identifier)
        candidates = [issue for issue in issues if aliases and issue.test_aliases & aliases]
        if len(candidates) == 1:
            candidates[0].attachments.append(path)
        else:
            unmatched.append(path)
    return sorted(dict.fromkeys(unmatched))


def build_report(args: argparse.Namespace) -> DiagnosticReport:
    result_bundle = Path(args.result_bundle).expanduser()
    log_path = Path(args.log).expanduser() if args.log else None
    sources = SourceStatus()
    accumulator = IssueAccumulator()
    failed_test_ids: list[str] = []

    if result_bundle.is_dir():
        build, error = xcresult.run_xcresulttool(result_bundle, ["get", "build-results"])
        if isinstance(build, dict):
            sources.build_results = True
            for observation in parse_build_results(build):
                accumulator.add(observation)
        elif error:
            sources.errors.append(error)

        summary, error = xcresult.run_xcresulttool(result_bundle, ["get", "test-results", "summary"])
        if isinstance(summary, dict):
            sources.test_summary = True
            for observation in parse_summary(summary):
                accumulator.add(observation)
        elif error:
            sources.errors.append(error)

        tests, error = xcresult.run_xcresulttool(result_bundle, ["get", "test-results", "tests"])
        if isinstance(tests, dict):
            sources.tests = True
            observations, failed_test_ids = parse_test_nodes(tests)
            for observation in observations:
                accumulator.add(observation)
        elif error:
            sources.errors.append(error)

        for test_id in failed_test_ids:
            detail, error = xcresult.run_xcresulttool(
                result_bundle,
                ["get", "test-results", "test-details", "--test-id", test_id],
            )
            if isinstance(detail, dict):
                sources.test_details += 1
                accumulator.add(parse_test_detail(detail, test_id))
            elif error:
                sources.errors.append(error)

    issues = accumulator.finalize()
    if not issues and log_path:
        fallback = IssueAccumulator()
        for observation in parse_log(log_path, args.exit_code):
            fallback.add(observation)
        issues = fallback.finalize()
    if not issues and args.exit_code != 0:
        issues = [DiagnosticIssue.from_observation(IssueObservation("unknown", "Xcode invocation", f"Xcode exited with code {args.exit_code}"))]

    issue_kinds = {issue.kind for issue in issues}
    classification = next((kind for kind in CLASSIFICATION_PRECEDENCE if kind in issue_kinds), "unknown")
    unmatched_attachments: list[str] = []
    output_stem = _output_stem(args.output_prefix)
    attachment_dir = Path(str(output_stem) + ".attachments")
    if result_bundle.is_dir() and (issues or args.exit_code != 0):
        exported, error = xcresult.export_failure_attachments(result_bundle, attachment_dir)
        sources.attachments = exported
        if error:
            sources.errors.append(f"attachment export: {error}")
        if exported:
            unmatched_attachments = assign_attachments(
                issues,
                attachment_dir,
                xcresult.read_exported_attachments(attachment_dir),
            )

    raw_log_path = ""
    if classification == "unknown" and log_path and args.exit_code != 0:
        raw_log_path = _normalise_path(str(log_path))
    return DiagnosticReport(
        label=args.label,
        result_bundle=_normalise_path(str(result_bundle)),
        log=_normalise_path(str(log_path)) if log_path else "",
        exit_code=args.exit_code,
        classification=classification,
        issues=issues,
        sources=sources,
        generated_at=datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        raw_log_path=raw_log_path,
        attachments=unmatched_attachments,
    )


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


def main(argv: list[str] | None = None) -> int:
    try:
        args = _parse_args(sys.argv[1:] if argv is None else argv)
        report = build_report(args)
        json_path, markdown_path, annotations_path = write_report(report, args.output_prefix)
        if not args.defer_terminal_output:
            print("\n".join(render_terminal(report)))
            if os.environ.get("GITHUB_ACTIONS", "").lower() == "true":
                print("\n".join(render_annotation(issue) for issue in report.issues[:MAX_ISSUES]))
            print(f"Report JSON: {json_path}", file=sys.stderr)
            print(f"Report Markdown: {markdown_path}", file=sys.stderr)
            print(f"Report annotations: {annotations_path}", file=sys.stderr)
        return 0
    except Exception as error:
        print(f"summarize-failures.py: reporter execution failed: {error}", file=sys.stderr)
        return 2
