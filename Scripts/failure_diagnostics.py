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

sys.path.insert(0, str(Path(__file__).resolve().parent))

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
    from diagnostic_rendering import output_stem, render_annotation, render_markdown, render_terminal, write_report
except ModuleNotFoundError:
    from Scripts.diagnostic_model import (
        CLASSIFICATIONS, CLASSIFICATION_PRECEDENCE, GENERIC_MESSAGES, MAX_ISSUES, MAX_LINES,
        DiagnosticIssue, DiagnosticReport, IssueAccumulator, IssueObservation, SourceStatus,
        identifier_aliases,
    )
    from Scripts.diagnostic_rendering import output_stem, render_annotation, render_markdown, render_terminal, write_report

try:
    from failure_diagnostics_parsers import (
        ACCESSIBILITY_SNAPSHOT_MARKER as ACCESSIBILITY_SNAPSHOT_MARKER,
        MAX_TEST_DETAIL_FETCHES as MAX_TEST_DETAIL_FETCHES,
        _display_path as _display_path,
        _prioritize_issues as _prioritize_issues,
        parse_build_results as parse_build_results,
        parse_log as parse_log,
        parse_summary as parse_summary,
        parse_test_detail as parse_test_detail,
        parse_test_nodes as parse_test_nodes,
    )
except ModuleNotFoundError:
    from Scripts.failure_diagnostics_parsers import (
        ACCESSIBILITY_SNAPSHOT_MARKER as ACCESSIBILITY_SNAPSHOT_MARKER,
        MAX_TEST_DETAIL_FETCHES as MAX_TEST_DETAIL_FETCHES,
        _display_path as _display_path,
        _prioritize_issues as _prioritize_issues,
        parse_build_results as parse_build_results,
        parse_log as parse_log,
        parse_summary as parse_summary,
        parse_test_detail as parse_test_detail,
        parse_test_nodes as parse_test_nodes,
    )


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

        for index, test_id in enumerate(failed_test_ids):
            if index >= MAX_TEST_DETAIL_FETCHES:
                sources.test_details_skipped += len(failed_test_ids) - MAX_TEST_DETAIL_FETCHES
                break
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
    issues = _prioritize_issues(issues)

    issue_kinds = {issue.kind for issue in issues}
    classification = next((kind for kind in CLASSIFICATION_PRECEDENCE if kind in issue_kinds), "unknown")
    unmatched_attachments: list[str] = []
    stem = output_stem(args.output_prefix)
    attachment_dir = Path(str(stem) + ".attachments")
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
        raw_log_path = _display_path(str(log_path))
    return DiagnosticReport(
        label=args.label,
        result_bundle=_display_path(str(result_bundle)),
        log=_display_path(str(log_path)) if log_path else "",
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
        print(f"failure_diagnostics.py: reporter execution failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
