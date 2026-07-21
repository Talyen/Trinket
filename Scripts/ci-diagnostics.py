#!/usr/bin/env python3
"""Aggregate structured diagnostics emitted by each CI test invocation."""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

if len(sys.argv) < 3:
    print("Usage: ci-diagnostics.py <RESULTS_DIR> <OUTPUT_PATH>", file=sys.stderr)
    sys.exit(1)

results_dir = Path(sys.argv[1]).resolve()
output_path = Path(sys.argv[2]).resolve()

# The order is deliberately stable. It keeps the aggregate category useful
# when a build emits more than one failed invocation (for example unit and UI).
CLASSIFICATION_PRECEDENCE = (
    "test-failure",
    "build-failure",
    "configuration",
    "tooling",
    "simulator-infrastructure",
    "unknown",
)
KNOWN_CLASSIFICATIONS = set(CLASSIFICATION_PRECEDENCE)


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def result_bundle_exists(value: object) -> bool:
    """Resolve a reporter's result bundle path without reparsing it."""
    if not isinstance(value, str) or not value.strip():
        return False

    candidate = Path(value)
    candidates = [candidate]
    if not candidate.is_absolute():
        candidates.extend((results_dir / candidate, Path.cwd() / candidate))
    return any(path.exists() for path in candidates)


def normalized_issue(issue: object) -> dict:
    # Reporter issues have a fixed schema. Keep malformed values bounded so
    # an accidental producer change cannot make the aggregate unreadable.
    if not isinstance(issue, dict):
        return {
            "id": "unknown",
            "kind": "unknown",
            "title": "Unstructured diagnostic",
            "message": str(issue),
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
    return {
        "id": str(issue.get("id", "unknown")),
        "kind": str(issue.get("kind", "unknown")),
        "title": str(issue.get("title", "Diagnostic")),
        "message": str(issue.get("message", "")),
        "file": str(issue.get("file", "")),
        "line": line,
        "test": str(issue.get("test", "")),
        "details": str(issue.get("details", "")),
        "attachments": [str(item) for item in attachments],
    }


def resolve_reference(value: object) -> Path | None:
    if not isinstance(value, str) or not value.strip():
        return None
    candidate = Path(value).expanduser()
    candidates = [candidate]
    if not candidate.is_absolute():
        candidates.extend((results_dir / candidate, Path.cwd() / candidate))
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
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def normalise_report(
    path: Path | None,
    payload: dict | None,
    *,
    manifest_path: Path | None = None,
    manifest: dict | None = None,
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
    has_result_bundle = result_bundle_exists(result_bundle)
    report_exists = path is not None and path.is_file()
    manifest_passed = status == "passed" and exit_code == 0 and has_result_bundle
    failed = (
        status != "passed"
        or exit_code != 0
        or not has_result_bundle
        or (not report_exists and not manifest_passed)
        or classification in KNOWN_CLASSIFICATIONS - {"unknown"}
    )
    raw_issues = payload.get("issues", [])
    if not isinstance(raw_issues, list):
        raw_issues = []
    issues = [normalized_issue(issue) for issue in raw_issues]
    if issues:
        # Reports are failure diagnostics; even an unknown issue must prevent
        # a manifest marked passed from becoming a false green aggregate.
        failed = True
    invocation = dict(payload)
    invocation.update(
        {
            "label": label,
            "classification": classification,
            "exit_code": exit_code,
            "status": status,
            "result_bundle": str(result_bundle or ""),
            "result_bundle_exists": has_result_bundle,
            "failed": failed,
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


def load_reports() -> tuple[list[dict], int, bool, int]:
    """Load current invocation manifests, falling back to reports for legacy callers."""
    manifests = sorted(results_dir.glob("*-invocation.json"))
    reports: list[dict] = []
    parse_errors = 0
    missing_diagnostics = 0
    if manifests:
        for manifest_path in manifests:
            manifest, valid = read_json(manifest_path)
            if not valid or manifest is None:
                parse_errors += 1
                missing_diagnostics += 1
                reports.append(
                    normalise_report(
                        None,
                        None,
                        manifest_path=manifest_path,
                        manifest={},
                    )
                )
                continue
            diagnostics_path = resolve_reference(manifest.get("diagnostics_json"))
            report_path = diagnostics_path
            payload = None
            manifest_passed = (
                str(manifest.get("status", "")).strip().lower() == "passed"
                and as_exit_code(manifest.get("exit_code", 1)) == 0
                and result_bundle_exists(manifest.get("result_bundle", ""))
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
                    manifest=manifest,
                )
            )
        return reports, parse_errors, True, missing_diagnostics

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
        reports.append(normalise_report(path, payload))
    return reports, parse_errors, False, 0


reports, parse_errors, manifests_present, missing_diagnostics_invocations = load_reports()
recorded_invocations = len(reports)
failed_reports = [report for report in reports if report["failed"]]
missing_result_invocations = sum(1 for report in reports if not report["result_bundle_exists"])

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
    detail = (
        f"All {recorded_invocations} recorded invocation(s) completed successfully "
        "with result bundles."
    )
elif failed_reports:
    labels = ", ".join(report["label"] for report in failed_reports)
    detail = (
        f"{len(failed_reports)} of {recorded_invocations} recorded invocation(s) "
        f"failed ({labels})."
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

aggregate_issues = []
for report in reports:
    for issue in report.get("issues", []):
        aggregate_issues.append({"label": report["label"], **issue})

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
    "missing_diagnostics_invocations": missing_diagnostics_invocations,
    "status_manifests_present": manifests_present,
    "counts": {
        "total": recorded_invocations,
        "failed": len(failed_reports),
        "missing_result": missing_result_invocations,
        "missing_diagnostics": missing_diagnostics_invocations,
        "by_classification": by_classification,
    },
    "invocations": reports,
    "issues": aggregate_issues,
}

output_path.parent.mkdir(parents=True, exist_ok=True)
with output_path.open("w", encoding="utf-8") as handle:
    json.dump(aggregate, handle, indent=2)
    handle.write("\n")

print(f"CI diagnostic category: {category} — {detail}")
if os.environ.get("GITHUB_STEP_SUMMARY"):
    summary_path = Path(os.environ["GITHUB_STEP_SUMMARY"])
    with summary_path.open("a", encoding="utf-8") as summary:
        summary.write("## CI diagnostics\n\n")
        summary.write(f"- **Category:** `{category}`\n")
        summary.write(f"- **Detail:** {detail}\n")
        summary.write(
            f"- **Invocations:** {recorded_invocations} recorded, "
            f"{len(failed_reports)} failed, {missing_result_invocations} missing xcresult, "
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
