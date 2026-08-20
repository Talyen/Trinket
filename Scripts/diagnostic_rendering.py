"""Bounded artifact and console rendering for diagnostic reports."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

try:
    from diagnostic_model import DiagnosticIssue, DiagnosticReport, MAX_ISSUES, MAX_LINES, bounded_text
except ModuleNotFoundError:
    from Scripts.diagnostic_model import DiagnosticIssue, DiagnosticReport, MAX_ISSUES, MAX_LINES, bounded_text


def _escape_annotation(value: str) -> str:
    return (
        str(value).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        .replace(":", "%3A").replace(",", "%2C")
    )


def render_annotation(issue: DiagnosticIssue) -> str:
    properties: list[str] = []
    if issue.file:
        properties.append(f"file={_escape_annotation(issue.file)}")
    if issue.line is not None:
        properties.append(f"line={issue.line}")
    properties.append(f"title={_escape_annotation(issue.title)}")
    fields = " " + ",".join(properties) if properties else ""
    return f"::error{fields}::{_escape_annotation(issue.message)}"


def _bounded_lines(lines: list[str], limit: int = MAX_LINES) -> list[str]:
    if len(lines) <= limit:
        return lines
    omitted = len(lines) - limit + 1
    return [*lines[: limit - 1], f"… {omitted} additional lines omitted by reporter"]


def render_markdown(report: DiagnosticReport) -> str:
    lines = [
        f"# Failure diagnostics: {report.label or 'Xcode'}", "",
        f"- Classification: `{report.classification}`",
        f"- Exit code: `{report.exit_code}`",
        f"- Issues: `{len(report.issues)}` (showing at most {MAX_ISSUES})", "", "## Issues",
    ]
    if not report.issues:
        lines.append("No structured failure issues were reported.")
    for index, issue in enumerate(report.issues[:MAX_ISSUES], 1):
        location = issue.file
        if issue.line is not None:
            location = f"{location}:{issue.line}" if location else f"line {issue.line}"
        suffix = f" — `{location}`" if location else ""
        test = f" ({issue.test})" if issue.test else ""
        lines.append(f"{index}. **{issue.title}**{test}{suffix}: {issue.message[:1200]}")
        detail_preview, detail_truncated = bounded_text(issue.details, line_limit=3)
        for detail in detail_preview.splitlines():
            lines.append(f"   - {detail}")
        if detail_truncated:
            lines.append("   - … additional detail is available in the raw log/result bundle")
        for attachment in issue.attachments:
            lines.append(f"   - Attachment: `{attachment}`")
    if len(report.issues) > MAX_ISSUES:
        lines.append(f"\n_{len(report.issues) - MAX_ISSUES} additional issues are available in the JSON report._")
    if report.attachments:
        lines.extend(["", "## Unassigned failure attachments"])
        lines.extend(f"- `{attachment}`" for attachment in report.attachments)
    if report.raw_log_path:
        lines.extend(["", f"Raw log: `{report.raw_log_path}`"])
    return "\n".join(_bounded_lines(lines)) + "\n"


def render_terminal(report: DiagnosticReport) -> list[str]:
    lines = [
        f"=== {report.label or 'Xcode'} failure diagnostics ===",
        f"Classification: {report.classification}",
        f"Exit code: {report.exit_code}",
        f"Issues: {len(report.issues)} (showing at most {MAX_ISSUES})",
    ]
    for index, issue in enumerate(report.issues[:MAX_ISSUES], 1):
        location = issue.file
        if issue.line is not None:
            location = f"{location}:{issue.line}" if location else f"line {issue.line}"
        location_suffix = f" [{location}]" if location else ""
        test_suffix = f" ({issue.test})" if issue.test else ""
        lines.append(f"{index}. {issue.kind}: {issue.title}{test_suffix}{location_suffix}")
        lines.append(f"   {issue.message[:1200]}")
        if issue.attachments:
            lines.append(f"   Attachments: {', '.join(issue.attachments)}")
    if len(report.issues) > MAX_ISSUES:
        lines.append(f"… {len(report.issues) - MAX_ISSUES} additional issues are available in the JSON report")
    if report.attachments:
        lines.append(f"Unassigned attachments: {', '.join(report.attachments)}")
    if report.raw_log_path:
        lines.append(f"Raw log: {report.raw_log_path}")
    return _bounded_lines(lines)


def _output_stem(value: str) -> Path:
    stem = Path(value).expanduser()
    if stem.suffix in {".json", ".md", ".annotations"}:
        stem = stem.with_suffix("")
    return stem


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def write_report(report: DiagnosticReport, output_prefix: str) -> tuple[Path, Path, Path]:
    stem = _output_stem(output_prefix)
    json_path = Path(str(stem) + ".json")
    markdown_path = Path(str(stem) + ".md")
    annotations_path = Path(str(stem) + ".annotations")
    _write_text(json_path, json.dumps(report.to_dict(), indent=2, sort_keys=False) + "\n")
    _write_text(markdown_path, render_markdown(report))
    annotation_lines = [render_annotation(issue) for issue in report.issues[:MAX_ISSUES]]
    _write_text(annotations_path, "\n".join(annotation_lines) + ("\n" if annotation_lines else ""))
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    per_invocation_summary = os.environ.get("TRINKET_DIAGNOSTICS_PER_INVOCATION_SUMMARY", "").lower() == "true"
    if summary_path and per_invocation_summary:
        try:
            with Path(summary_path).open("a", encoding="utf-8") as stream:
                stream.write("\n" + render_markdown(report))
        except OSError as error:
            report.sources.errors.append(f"GitHub step summary: {error}")
            print(f"summarize-failures.py: could not write GITHUB_STEP_SUMMARY: {error}", file=sys.stderr)
            _write_text(json_path, json.dumps(report.to_dict(), indent=2, sort_keys=False) + "\n")
    return json_path, markdown_path, annotations_path
