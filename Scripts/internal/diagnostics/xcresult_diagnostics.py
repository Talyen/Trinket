#!/usr/bin/env python3
"""Process-boundary helpers for public xcresulttool diagnostics APIs."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from collections.abc import Iterator

from internal.cli import write_json_atomic


def walk_test_nodes(node: Any) -> Iterator[dict[str, Any]]:
    """Walk current children and legacy subtests in source order without recursion."""
    pending = [node]
    while pending:
        current = pending.pop()
        if isinstance(current, list):
            pending.extend(reversed(current))
        elif isinstance(current, dict):
            yield current
            subtests = current.get("subtests")
            if isinstance(subtests, dict):
                subtests = subtests.get("_values")
            pending.extend((subtests, current.get("children")))


@dataclass(frozen=True)
class ExportedAttachment:
    exported_file_name: str
    test_identifier: str
    associated_with_failure: bool


# xcresulttool can hang indefinitely on partial or corrupt bundles (common after a
# watchdog kill); every call is bounded so diagnostics degrade instead of stalling.
QUERY_TIMEOUT_SECONDS = 120
ATTACHMENT_EXPORT_TIMEOUT_SECONDS = 300


def capture_simulator_context(output_dir: Path, udid: str, expected_name: str) -> list[str]:
    """Best-effort post-failure evidence through simctl, independent of XCTest AX."""
    if not expected_name or not re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", udid):
        return []
    output_dir.mkdir(parents=True, exist_ok=True)
    context = {"udid": udid, "expected_name": expected_name, "phase": "after-test-invocation", "errors": []}
    files = []

    def query(*arguments: str) -> str | None:
        try:
            result = subprocess.run(["xcrun", "simctl", *arguments], capture_output=True,
                                    text=True, check=False, timeout=10)
            if result.returncode == 0:
                return result.stdout
            context["errors"].append(f"{arguments[0]} exited {result.returncode}: {result.stderr[:1000]}")
        except (OSError, subprocess.TimeoutExpired) as error:
            context["errors"].append(str(error)[:1000])
        return None

    inventory = query("list", "devices", udid, "-j")
    try:
        devices = json.loads(inventory or "{}").get("devices", {})
        device = next((item for group in devices.values() for item in group if item.get("udid") == udid), {})
    except (ValueError, AttributeError, TypeError):
        device = {}
    context["device"] = device
    if device.get("name") == expected_name and device.get("state") == "Booted":
        screenshot = output_dir / "simulator-after-failure.png"
        screenshot.unlink(missing_ok=True)
        query("io", udid, "screenshot", str(screenshot))
        signature = b""
        if screenshot.is_file():
            with screenshot.open("rb") as image:
                signature = image.read(8)
        if signature == b"\x89PNG\r\n\x1a\n":
            files.append(str(screenshot))
        else:
            screenshot.unlink(missing_ok=True)
            context["errors"].append("simctl did not produce a PNG screenshot")
        log_path = output_dir / "simulator-recent.log"
        log_path.unlink(missing_ok=True)
        logs = query("spawn", udid, "log", "show", "--last", "2m", "--style", "compact", "--predicate",
                     'process == "Trinket" OR process == "TrinketUITests-Runner" OR process == "testmanagerd"')
        if logs is not None:
            log_path.write_text(logs[-65536:])
            files.append(str(log_path))
    else:
        context["errors"].append("Simulator ownership/name or booted state could not be confirmed; capture skipped")
    context_path = output_dir / "simulator-context.json"
    context_path.write_text(json.dumps(context, indent=2) + "\n")
    return [str(context_path), *files]


def bundle_identity(bundle: Path) -> dict | None:
    """Completed invocation paths and filesystem generations must both match."""
    try:
        root, info = bundle.stat(), (bundle / "Info.plist").stat()
        return {"path": str(bundle.resolve()), "bundle": [root.st_dev, root.st_ino, root.st_mtime_ns, root.st_ctime_ns],
                "info": [info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns]}
    except OSError:
        return None


def report_shape(kind: str, payload: Any) -> bool:
    return isinstance(payload, dict) and (
        isinstance(payload.get("testNodes"), list) if kind == "tests"
        else isinstance(payload.get("result"), str)
    )


def run_xcresulttool(
    result_bundle: Path,
    arguments: list[str],
    timeout_seconds: int = QUERY_TIMEOUT_SECONDS,
) -> tuple[Any | None, str | None]:
    """Run a supported xcresulttool report API and decode its JSON output."""

    kind = arguments[2] if arguments in (["get", "test-results", "tests"],
                                         ["get", "test-results", "summary"]) else None
    identity = bundle_identity(result_bundle) if kind else None
    cache = result_bundle.with_name(result_bundle.stem + "-xcresult-reports") / f"{kind}.json"
    if identity is not None:
        try:
            saved = json.loads(cache.read_text())
            if (isinstance(saved, dict) and type(saved.get("schema_version")) is int and saved["schema_version"] == 1
                    and saved.get("identity") == identity and report_shape(kind, saved.get("payload"))
                    and bundle_identity(result_bundle) == identity):
                return saved["payload"], None
        except (OSError, ValueError):
            pass

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
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        return None, f"{' '.join(command)} returned invalid JSON: {error}"
    if identity is not None and bundle_identity(result_bundle) == identity and report_shape(kind, payload):
        try:
            cache.parent.mkdir(exist_ok=True)
            write_json_atomic(cache, {"schema_version": 1, "identity": identity, "payload": payload})
        except OSError:
            pass  # Optional reuse must not change the exported result or verdict.
    return payload, None


def export_failure_attachments(
    result_bundle: Path,
    output_dir: Path,
    timeout_seconds: int = ATTACHMENT_EXPORT_TIMEOUT_SECONDS,
) -> tuple[bool, str | None]:
    # This directory is a derived export: reusing it would attach screenshots
    # from an earlier invocation to the current failures.
    try:
        if output_dir.exists():
            shutil.rmtree(output_dir)
        output_dir.mkdir(parents=True)
    except OSError as error:
        return False, f"could not prepare attachment export: {error}"
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
    for path in sorted(output_dir.rglob("*")):
        name = path.relative_to(output_dir).as_posix()
        if path.is_file() and path != manifest and name not in recorded_names:
            records.append(
                ExportedAttachment(
                    exported_file_name=name,
                    test_identifier="",
                    associated_with_failure=True,
                )
            )
    return records
