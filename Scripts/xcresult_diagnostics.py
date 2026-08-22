#!/usr/bin/env python3
"""Process-boundary helpers for public xcresulttool diagnostics APIs."""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class ExportedAttachment:
    exported_file_name: str
    test_identifier: str
    associated_with_failure: bool


# xcresulttool can hang indefinitely on partial or corrupt bundles (common after a
# watchdog kill); every call is bounded so diagnostics degrade instead of stalling.
QUERY_TIMEOUT_SECONDS = 120
ATTACHMENT_EXPORT_TIMEOUT_SECONDS = 300


def run_xcresulttool(
    result_bundle: Path,
    arguments: list[str],
    timeout_seconds: int = QUERY_TIMEOUT_SECONDS,
) -> tuple[Any | None, str | None]:
    """Run a supported xcresulttool report API and decode its JSON output."""

    command = ["xcrun", "xcresulttool", *arguments, "--path", str(result_bundle), "--compact"]
    try:
        completed = subprocess.run(
            command, capture_output=True, text=True, check=False, timeout=timeout_seconds
        )
    except subprocess.TimeoutExpired:
        return None, f"{' '.join(command)} timed out after {timeout_seconds}s"
    except OSError as error:
        return None, f"could not execute {' '.join(command[:3])}: {error}"
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "command failed").strip()
        return None, f"{' '.join(command)} exited {completed.returncode}: {detail[:500]}"
    try:
        return json.loads(completed.stdout), None
    except json.JSONDecodeError as error:
        return None, f"{' '.join(command)} returned invalid JSON: {error}"


def export_failure_attachments(
    result_bundle: Path,
    output_dir: Path,
    timeout_seconds: int = ATTACHMENT_EXPORT_TIMEOUT_SECONDS,
) -> tuple[bool, str | None]:
    output_dir.mkdir(parents=True, exist_ok=True)
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
        completed = subprocess.run(
            command, capture_output=True, text=True, check=False, timeout=timeout_seconds
        )
    except subprocess.TimeoutExpired:
        return False, f"attachment export timed out after {timeout_seconds}s"
    except OSError as error:
        return False, str(error)
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "attachment export failed").strip()
        return False, detail[:500]
    return True, None


def read_exported_attachments(output_dir: Path) -> list[ExportedAttachment]:
    """Read attachment ownership retained by xcresulttool's export manifest."""

    manifest = output_dir / "manifest.json"
    try:
        payload = json.loads(manifest.read_text(encoding="utf-8")) if manifest.exists() else []
    except (OSError, json.JSONDecodeError):
        payload = []
    if not isinstance(payload, list):
        payload = []

    records: list[ExportedAttachment] = []
    for test_entry in payload:
        if not isinstance(test_entry, dict):
            continue
        test_identifier = str(test_entry.get("testIdentifier", "")).strip()
        attachments = test_entry.get("attachments", [])
        if not isinstance(attachments, list):
            continue
        for attachment in attachments:
            if not isinstance(attachment, dict):
                continue
            exported_file_name = str(attachment.get("exportedFileName", "")).strip()
            if exported_file_name:
                records.append(
                    ExportedAttachment(
                        exported_file_name=exported_file_name,
                        test_identifier=test_identifier,
                        associated_with_failure=attachment.get("isAssociatedWithFailure") is True,
                    )
                )
    recorded_names = {record.exported_file_name for record in records}
    for path in output_dir.rglob("*"):
        if path.is_file() and path.name != "manifest.json" and path.name not in recorded_names:
            records.append(
                ExportedAttachment(
                    exported_file_name=path.name,
                    test_identifier="",
                    associated_with_failure=True,
                )
            )
    return records
