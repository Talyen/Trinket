#!/usr/bin/env python3
"""Aggregate structured diagnostics emitted by each CI test invocation."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

from ci_ui_retry import recovery_valid

from internal.diagnostics.diagnostic_limits import MAX_AGGREGATE_ISSUES, MAX_LABELS_IN_DETAIL, MAX_MESSAGE_CHARS
from internal.diagnostics.diagnostic_model import CLASSIFICATION_PRECEDENCE, bounded_text


def parse_args(argv: list[str], environ: dict[str, str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--full', action='store_true')
    parser.add_argument('results_dir', type=Path)
    parser.add_argument('output_path', type=Path)
    args = parser.parse_args(argv)
    args.results_dir = args.results_dir.resolve()
    args.output_path = args.output_path.resolve()
    args.session_id = environ.get('TRINKET_DIAGNOSTICS_SESSION_ID', '').strip()
    return args


# Classification precedence is owned by diagnostic_model (single source); the
# order keeps the aggregate category useful when a build emits more than one
# failed invocation (for example unit and UI).
KNOWN_CLASSIFICATIONS = set(CLASSIFICATION_PRECEDENCE)


def compact_text(value: object, *, limit: int | None = None) -> str:
    """Normalize repeated machine paths and whitespace before exposing text to agents."""
    text = re.sub(r"\s+", " ", str(value or "").strip())
    for prefix, replacement in (
        (str(Path.cwd()), "<repo>"),
        (str(Path.home()), "<home>"),
    ):
        text = text.replace(prefix, replacement)
    text = re.sub(r"/private/tmp/[^/ ]+", "<tmp>", text)
    if limit is not None and len(text) > limit:
        text = f"{text[:limit - 1]}…"
    return text


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _resolve_bundle_candidates(value: str, results_dir: Path | None = None) -> list[Path]:
    candidate = Path(value).expanduser()
    candidates = [candidate]
    if not candidate.is_absolute():
        candidates.extend(((results_dir or Path.cwd()) / candidate, Path.cwd() / candidate))
    return candidates


def result_bundle_exists(value: object, results_dir: Path | None = None) -> bool:
    """Resolve a reporter's result bundle path without reparsing it."""
    if not isinstance(value, str) or not value.strip():
        return False
    return any(path.is_dir() for path in _resolve_bundle_candidates(value, results_dir))


def result_bundle_complete(value: object, results_dir: Path | None = None) -> bool:
    """A finalized xcresult has a root Info.plist; partial watchdog output does not."""
    if not isinstance(value, str) or not value.strip():
        return False
    return any((path / "Info.plist").is_file() for path in _resolve_bundle_candidates(value, results_dir))


def watchdog_log_proves_pass(manifest: dict, status: str, exit_code: int) -> bool:
    return (
        status == "passed"
        and exit_code == 0
        and manifest.get("completion_source") == "watchdog-log-inference"
        and manifest.get("test_execution_proven") is True
    )


def successful_build(manifest: dict) -> bool:
    return (
        manifest.get("action") in {"build", "build-for-testing"}
        and manifest.get("status") == "passed"
        and as_exit_code(manifest.get("exit_code")) == 0
        and manifest.get("completion_source") == "process-exit"
    )


def normalized_issue(issue: object) -> dict:
    # Reporter issues have a fixed schema. Keep malformed values bounded so
    # an accidental producer change cannot make the aggregate unreadable.
    if not isinstance(issue, dict):
        return {
            "id": "unknown",
            "kind": "unknown",
            "title": "Unstructured diagnostic",
            "message": compact_text(issue, limit=MAX_MESSAGE_CHARS),
            "file": "",
            "line": None,
            "test": "",
            "details": "",
            "attachments": [],
        }

    line = issue.get("line")
    if not isinstance(line, int) or isinstance(line, bool):
        line = None
    attachments = issue.get("attachments")
    if not isinstance(attachments, list):
        attachments = []
    details = str(issue.get("details", ""))
    normalized_details = "\n".join(compact_text(line) for line in details.splitlines())
    bounded_details, details_truncated = bounded_text(normalized_details)
    details_truncated = details_truncated or issue.get("details_truncated") is True
    message = compact_text(issue.get("message", ""), limit=MAX_MESSAGE_CHARS)
    return {
        "id": str(issue.get("id", "unknown")),
        "kind": str(issue.get("kind", "unknown")),
        "title": str(issue.get("title", "Diagnostic")),
        "message": message,
        "file": str(issue.get("file", "")),
        "line": line,
        "test": str(issue.get("test", "")),
        "details": bounded_details,
        "details_truncated": details_truncated,
        "attachments": [str(item) for item in attachments],
    }


def resolve_reference(value: object, results_dir: Path) -> Path | None:
    if not isinstance(value, str) or not value.strip():
        return None
    candidates = _resolve_bundle_candidates(value, results_dir)
    for path in candidates:
        if path.exists():
            return path.resolve()
    return candidates[0].resolve() if candidates[0].is_absolute() else (Path.cwd() / candidates[0]).resolve()


def read_json(path: Path) -> tuple[dict | None, bool]:
    try:
        with path.open(encoding="utf-8") as handle:
            payload = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return None, False
    return (payload, True) if isinstance(payload, dict) else (None, False)


def as_exit_code(value: object, default: int = 1) -> int:
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if isinstance(value, str):
        try:
            return int(value)
        except ValueError:
            pass
    return default


def normalise_report(
    path: Path | None,
    payload: dict | None,
    *,
    manifest_path: Path | None = None,
    manifest: dict | None = None,
    results_dir: Path | None = None,
    full: bool = False,
) -> dict:
    payload = payload or {}
    manifest = manifest or {}
    label = str(manifest.get("label", payload.get("label", ""))).strip()
    if not label:
        label = path.stem.removesuffix("-diagnostics") if path else "unknown"
    classification = payload.get("classification")
    if classification not in KNOWN_CLASSIFICATIONS:
        classification = "unknown"
    exit_code = as_exit_code(manifest.get("exit_code", payload.get("exit_code", 1)))
    status = str(manifest.get("status", "")).strip().lower()
    if status not in {"passed", "failed"}:
        if manifest_path is None:
            status = "failed" if exit_code != 0 else "passed"
        else:
            status = "failed" if exit_code != 0 else "unknown"
    result_bundle = manifest.get("result_bundle", payload.get("result_bundle", ""))
    has_result_bundle = result_bundle_exists(result_bundle, results_dir)
    has_complete_result_bundle = result_bundle_complete(result_bundle, results_dir)
    has_watchdog_proof = watchdog_log_proves_pass(manifest, status, exit_code)
    has_build_proof = successful_build(manifest)
    report_exists = path is not None and path.is_file()
    manifest_passed = (
        status == "passed"
        and exit_code == 0
        and (has_complete_result_bundle or has_watchdog_proof or has_build_proof)
    )
    failed = (
        status != "passed"
        or exit_code != 0
        or not (has_complete_result_bundle or has_watchdog_proof or has_build_proof)
        or (not report_exists and not manifest_passed)
        or classification in KNOWN_CLASSIFICATIONS - {"unknown"}
    )
    raw_issues = payload.get("issues", [])
    if not isinstance(raw_issues, list):
        raw_issues = []
    if full:
        issues = [dict(issue) if isinstance(issue, dict) else normalized_issue(issue) for issue in raw_issues]
    else:
        issues = [normalized_issue(issue) for issue in raw_issues]
    if issues:
        # Reports are failure diagnostics; even an unknown issue must prevent
        # a manifest marked passed from becoming a false green aggregate.
        failed = True
    recovered = recovery_valid(manifest, payload)
    if recovered:
        failed = False
    invocation = dict(payload)
    invocation.update(
        {
            "label": label,
            "action": manifest.get("action", "unknown"),
            "classification": classification,
            "exit_code": exit_code,
            "status": status,
            "result_bundle": str(result_bundle or ""),
            "result_bundle_exists": has_result_bundle,
            "result_bundle_complete": has_complete_result_bundle,
            "completion_source": str(manifest.get("completion_source", "")),
            "test_execution_proven": manifest.get("test_execution_proven") is True,
            "failed": failed,
            "infrastructure_recovered": recovered,
            "diagnostics_exists": report_exists,
            "diagnostic_path": str(path) if path else "",
            "issues": issues,
        }
    )
    if manifest_path:
        invocation["invocation_manifest"] = str(manifest_path)
    diagnostics_json = manifest.get("diagnostics_json")
    if diagnostics_json:
        invocation["diagnostics_json"] = str(diagnostics_json)
    # A raw log path is intentionally retained only for an unknown,
    # unsuccessful diagnosis. Successful reports do not expose raw logs.
    if classification != "unknown" or (exit_code == 0 and has_result_bundle and not failed):
        invocation.pop("raw_log_path", None)
    return invocation


def load_reports(results_dir: Path, output_path: Path, session_id: str, full: bool) -> tuple[list[dict], int, bool, int, str, int]:
    """Load current invocation manifests, falling back to reports for legacy callers.

    The final value counts the distinct non-empty session ids present in the
    directory, so shared tenants can warn when stale sessions dilute triage.
    """
    manifests = [(path, *read_json(path)) for path in sorted(results_dir.glob("*-invocation.json"))]
    selected_session = session_id
    distinct_sessions: set[str] = set()
    if manifests and not selected_session:
        session_candidates: list[tuple[str, str]] = []
        for _, payload, valid in manifests:
            if not valid or payload is None:
                continue
            session = str(payload.get("session_id", "")).strip()
            if not session:
                continue
            distinct_sessions.add(session)
            session_candidates.append(
                (str(payload.get("generated_at", "")), session)
            )
        if session_candidates:
            selected_session = max(session_candidates)[1]
    if selected_session:
        manifests = [(path, payload, valid) for path, payload, valid in manifests
                     if valid and payload and str(payload.get("session_id", "")).strip() == selected_session]
    reports: list[dict] = []
    parse_errors = 0
    missing_diagnostics = 0
    if manifests:
        for manifest_path, manifest, valid in manifests:
            if not valid or manifest is None:
                parse_errors += 1
                missing_diagnostics += 1
                reports.append(
                    normalise_report(
                        None,
                        None,
                        manifest_path=manifest_path,
                        manifest={}, results_dir=results_dir, full=full,
                    )
                )
                continue
            diagnostics_path = resolve_reference(manifest.get("diagnostics_json"), results_dir)
            report_path = diagnostics_path
            payload = None
            manifest_passed = (
                str(manifest.get("status", "")).strip().lower() == "passed"
                and as_exit_code(manifest.get("exit_code", 1)) == 0
                and (
                    result_bundle_complete(manifest.get("result_bundle", ""), results_dir)
                    or watchdog_log_proves_pass(manifest, "passed", 0)
                    or successful_build(manifest)
                )
            )
            if diagnostics_path and diagnostics_path.is_file():
                payload, valid_report = read_json(diagnostics_path)
                if not valid_report:
                    if not manifest_passed:
                        parse_errors += 1
                        missing_diagnostics += 1
                    report_path = None
                    payload = None
            else:
                if not manifest_passed:
                    missing_diagnostics += 1
            reports.append(
                normalise_report(
                    report_path,
                    payload,
                    manifest_path=manifest_path,
                    manifest=manifest, results_dir=results_dir, full=full,
                )
            )
        return reports, parse_errors, True, missing_diagnostics, selected_session, len(distinct_sessions)

    # Compatibility for local/older producers that only emitted diagnostics.
    # Without a status manifest a successful outcome is not considered proven;
    # failed classifications are still surfaced for actionable triage.
    for path in sorted(results_dir.glob("*-diagnostics.json")):
        if path.resolve() == output_path:
            continue
        payload, valid = read_json(path)
        if not valid:
            parse_errors += 1
            continue
        reports.append(normalise_report(path, payload, results_dir=results_dir, full=full))
    return reports, parse_errors, False, 0, selected_session, len(distinct_sessions)


def main(argv: list[str] | None = None, environ: dict[str, str] | None = None) -> int:
    """Aggregate invocation diagnostics. Pure orchestration; safe to import."""
    environ = dict(os.environ) if environ is None else environ
    args = parse_args(list(sys.argv[1:] if argv is None else argv), environ)
    results_dir, output_path = args.results_dir, args.output_path
    full = args.full

    reports, parse_errors, manifests_present, missing_diagnostics_invocations, selected_session, distinct_session_count = load_reports(results_dir, output_path, args.session_id, full)
    recorded_invocations = len(reports)
    failed_reports = [report for report in reports if report["failed"]]
    missing_result_invocations = sum(1 for report in reports if not report["result_bundle_exists"] and report["action"] not in {"build", "build-for-testing"})
    incomplete_result_invocations = sum(
        1 for report in reports if not report["result_bundle_complete"] and report["action"] not in {"build", "build-for-testing"}
    )

    by_classification = {classification: 0 for classification in CLASSIFICATION_PRECEDENCE}
    for report in reports:
        by_classification[report["classification"]] += 1

    if failed_reports:
        failed_classes = {report["classification"] for report in failed_reports}
        category = next(
            classification
            for classification in CLASSIFICATION_PRECEDENCE
            if classification in failed_classes
        )
    elif manifests_present and recorded_invocations and not parse_errors:
        # Reporter uses unknown for a successful invocation with no issues. The
        # exit code and result bundle, rather than that sentinel, determine pass.
        category = "passed"
    else:
        # No current status manifest means the outcome cannot be proven. In
        # particular, do not infer a pass from a stale report or an unparsed log.
        category = "unknown"

    if category == "passed":
        recovered_count = sum(report.get("infrastructure_recovered", False) for report in reports)
        detail = f"All {recorded_invocations} recorded invocation(s) completed successfully."
        if recovered_count:
            detail = (f"All {recorded_invocations} recorded invocation(s) passed or recovered with verified targeted execution. "
                      f"{recovered_count} infrastructure failure(s) recovered by retrying only failed cases.")
        if incomplete_result_invocations:
            detail += (
                f" {incomplete_result_invocations} invocation(s) used watchdog log proof "
                "because Xcode did not finalize the xcresult bundle."
            )
    elif failed_reports:
        labels = [compact_text(report["label"], limit=80) for report in failed_reports]
        label_preview = ", ".join(labels[:MAX_LABELS_IN_DETAIL])
        if len(labels) > MAX_LABELS_IN_DETAIL:
            label_preview += f", +{len(labels) - MAX_LABELS_IN_DETAIL} more"
        detail = (
            f"{len(failed_reports)} of {recorded_invocations} recorded invocation(s) "
            f"failed ({label_preview})."
        )
        if missing_result_invocations:
            detail += f" {missing_result_invocations} invocation(s) had no xcresult bundle."
        if missing_diagnostics_invocations:
            detail += f" {missing_diagnostics_invocations} invocation(s) had no diagnostics report."
    elif parse_errors:
        detail = (
            f"No usable invocation diagnostics were recorded; {parse_errors} diagnostic "
            "file(s) could not be parsed. Escalate with the raw CI logs."
        )
    elif recorded_invocations and not manifests_present:
        detail = (
            f"{recorded_invocations} invocation diagnostic(s) were found without a current "
            "status manifest. The outcome is unknown; rerun with the CI runner manifest."
        )
    else:
        detail = (
            "No invocation diagnostics were recorded. The outcome is unknown; "
            "escalate with the raw CI logs."
        )

    # Shared tenants accumulate sessions from crashed or unscoped runs; without a
    # session id the aggregate silently covers only the newest one. Say so instead
    # of letting a green summary hide stale red state (or the reverse).
    session_warning = ""
    if manifests_present and not args.session_id and distinct_session_count > 1:
        session_warning = (
            f"{distinct_session_count} diagnostics sessions share this results directory; "
            "this aggregate covers only the newest session. Scope with "
            "TRINKET_DIAGNOSTICS_SESSION_ID or clear stale state with "
            "./Scripts/ci-diagnostics.sh --reset."
        )
        detail = f"{detail} Warning: {session_warning}"

    def compact_invocation(report: dict) -> dict:
        """Keep the default aggregate useful without embedding full reports."""
        issues = report.get("issues", [])
        return {
            "label": report.get("label", ""),
            "action": report.get("action", "unknown"),
            "classification": report.get("classification", "unknown"),
            "exit_code": report.get("exit_code", 1),
            "status": report.get("status", "unknown"),
            "failed": report.get("failed", True),
            "infrastructure_recovered": report.get("infrastructure_recovered", False),
            "result_bundle_exists": report.get("result_bundle_exists", False),
            "result_bundle_complete": report.get("result_bundle_complete", False),
            "diagnostics_exists": report.get("diagnostics_exists", False),
            "diagnostic_path": report.get("diagnostic_path", ""),
            "invocation_manifest": report.get("invocation_manifest", ""),
            "issue_count": len(issues) if isinstance(issues, list) else 0,
        }


    aggregate_issues = []
    issues_by_key: dict[tuple[str, str, str], dict] = {}
    for report in reports:
        for issue in report.get("issues", []):
            if full:
                aggregate_issues.append({"label": report["label"], **issue})
                continue
            key = (report["label"], str(issue.get("id", "unknown")), str(issue.get("message", "")))
            if key in issues_by_key:
                issues_by_key[key]["occurrences"] += 1
            else:
                grouped = {**issue, "label": report["label"], "occurrences": 1}
                issues_by_key[key] = grouped
                aggregate_issues.append(grouped)

    aggregate_issues_total = len(aggregate_issues)
    if not full:
        aggregate_issues = aggregate_issues[:MAX_AGGREGATE_ISSUES]

    generated_at = iso_now()
    aggregate = {
        "schema_version": 1,
        "generated_at": generated_at,
        # Keep the historic fields consumed by workflow summaries and agents.
        "recorded_at": generated_at,
        "category": category,
        "detail": detail,
        "recorded_invocations": recorded_invocations,
        "failed_invocations": len(failed_reports),
        "missing_result_invocations": missing_result_invocations,
        "incomplete_result_invocations": incomplete_result_invocations,
        "missing_diagnostics_invocations": missing_diagnostics_invocations,
        "status_manifests_present": manifests_present,
        "session_id": selected_session,
        "session_filter": selected_session or "unscoped",
        "distinct_sessions": distinct_session_count,
        "session_warning": session_warning,
        "counts": {
            "total": recorded_invocations,
            "failed": len(failed_reports),
            "missing_result": missing_result_invocations,
            "incomplete_result": incomplete_result_invocations,
            "missing_diagnostics": missing_diagnostics_invocations,
            "by_classification": by_classification,
        },
        "invocations": reports if full else [compact_invocation(report) for report in reports],
        "issues": aggregate_issues,
        "issues_total": aggregate_issues_total,
        "issues_truncated": aggregate_issues_total > MAX_AGGREGATE_ISSUES,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        json.dump(aggregate, handle, indent=2)
        handle.write("\n")

    print(f"CI diagnostic category: {category} — {detail}")
    if environ.get("GITHUB_STEP_SUMMARY"):
        summary_path = Path(environ["GITHUB_STEP_SUMMARY"])
        with summary_path.open("a", encoding="utf-8") as summary:
            summary.write("## CI diagnostics\n\n")
            summary.write(f"- **Category:** `{category}`\n")
            summary.write(f"- **Detail:** {detail}\n")
            if session_warning:
                summary.write(f"- **Sessions:** {session_warning}\n")
            summary.write(
                f"- **Invocations:** {recorded_invocations} recorded, "
                f"{len(failed_reports)} failed, {missing_result_invocations} missing xcresult, "
                f"{incomplete_result_invocations} incomplete xcresult, "
                f"{missing_diagnostics_invocations} missing diagnostics\n"
            )
            if aggregate_issues:
                summary.write("\n### Actionable diagnostics\n\n")
                for issue in aggregate_issues[:20]:
                    title = issue["title"] or issue["kind"]
                    message = issue["message"] or issue["details"] or "No details provided."
                    summary.write(f"- `{issue['label']}` — **{title}:** {message}\n")
            if category == "unknown":
                summary.write(
                    "\nThe category is unknown. Escalate by inspecting the raw CI logs; "
                    "otherwise consume the structured invocation diagnostics above.\n"
                )

    return 0


if __name__ == "__main__":
    sys.exit(main())
