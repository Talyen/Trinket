#!/usr/bin/env python3
"""Measure routed command output without retaining command output.

The ``run`` command is deliberately a small process boundary: child output is
forwarded to its original stdout/stderr streams while only counts and timing
metadata are written to the profile directory.  ``report`` turns those
metadata-only records into a bounded, advisory hotspot report.
"""

from __future__ import annotations

import argparse
import datetime as _datetime
import fcntl
import json
import math
import os
from pathlib import Path
import selectors
import signal
import statistics
import subprocess
import sys
import tempfile
import time
import uuid
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_VERSION = 1
LINE_BUDGET = 60
BYTE_BUDGET = 14_400
TREND_RATIO = 1.5
TREND_LINE_DELTA = 20
TREND_BYTE_DELTA = 4_096
TREND_SAMPLE_COUNT = 5
RECURRING_SAMPLE_COUNT = 5
RECURRING_MINIMUM = 3
LOCAL_RETENTION = 50
DEFAULT_PROFILE_DIRECTORY = Path(__file__).resolve().parents[1] / ".DerivedData" / "OutputProfiles"


def profile_directory(override: str | os.PathLike[str] | None = None) -> Path:
    """Return the configured profile directory without creating it."""

    if override is not None:
        return Path(override).expanduser()
    configured = os.environ.get("TRINKET_OUTPUT_PROFILE_DIR")
    if configured:
        return Path(configured).expanduser()
    return DEFAULT_PROFILE_DIRECTORY


def infer_environment(explicit: str | None = None) -> str:
    if explicit:
        return explicit
    configured = os.environ.get("TRINKET_OUTPUT_PROFILE_ENV", "").strip().lower()
    if configured in {"local", "ci"}:
        return configured
    if os.environ.get("GITHUB_ACTIONS", "").lower() == "true":
        return "ci"
    if os.environ.get("CI", "").lower() in {"1", "true", "yes"}:
        return "ci"
    return "local"


def utc_timestamp() -> str:
    return _datetime.datetime.now(_datetime.timezone.utc).isoformat(timespec="milliseconds")


def parse_iso_timestamp(value: str) -> _datetime.datetime:
    """Parse an ISO-8601 timestamp as an aware UTC datetime."""

    normalized = value.strip()
    if not normalized:
        raise ValueError("--since must be a non-empty ISO-8601 timestamp")
    if normalized.endswith(("Z", "z")):
        normalized = normalized[:-1] + "+00:00"
    try:
        parsed = _datetime.datetime.fromisoformat(normalized)
    except ValueError as error:
        raise ValueError("--since must be a valid ISO-8601 timestamp") from error
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=_datetime.timezone.utc)
    return parsed.astimezone(_datetime.timezone.utc)


def _positive_integer(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("must be a positive integer") from error
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return parsed


def _write_all(destination: Any, chunk: bytes) -> bool:
    """Write bytes to a standard stream, tolerating a closed consumer."""

    if not chunk:
        return True
    try:
        destination.write(chunk)
        destination.flush()
        return True
    except (BrokenPipeError, OSError):
        return False


class _StreamCounter:
    def __init__(self, destination: Any) -> None:
        self.destination = destination
        self.byte_count = 0
        self.newline_count = 0
        self.saw_bytes = False
        self.last_byte: int | None = None
        self.output_closed = False

    def consume(self, chunk: bytes) -> None:
        self.byte_count += len(chunk)
        self.newline_count += chunk.count(b"\n")
        self.saw_bytes = True
        self.last_byte = chunk[-1]
        if not self.output_closed and not _write_all(self.destination, chunk):
            self.output_closed = True

    def finish(self) -> int:
        if not self.saw_bytes:
            return 0
        return self.newline_count + (0 if self.last_byte == ord("\n") else 1)


def _stream_process(process: subprocess.Popen[bytes]) -> dict[str, int]:
    """Forward both child streams while counting bytes and displayed lines."""

    stdout = getattr(sys.stdout, "buffer", sys.stdout)
    stderr = getattr(sys.stderr, "buffer", sys.stderr)
    counters = {
        "stdout": _StreamCounter(stdout),
        "stderr": _StreamCounter(stderr),
    }
    selector = selectors.DefaultSelector()
    streams = ((process.stdout, counters["stdout"]), (process.stderr, counters["stderr"]))
    for stream, counter in streams:
        if stream is not None:
            selector.register(stream, selectors.EVENT_READ, counter)

    old_handlers: dict[int, Any] = {}

    def forward(signum: int, _frame: Any) -> None:
        if process.poll() is None:
            try:
                process.send_signal(signum)
            except ProcessLookupError:
                pass

    for signum in (signal.SIGINT, signal.SIGTERM):
        try:
            old_handlers[signum] = signal.getsignal(signum)
            signal.signal(signum, forward)
        except (OSError, ValueError):
            # Signal registration is only available in the main interpreter
            # thread.  The child still runs correctly when imported by tests.
            pass

    try:
        while selector.get_map():
            try:
                ready = selector.select(timeout=0.25)
            except InterruptedError:
                continue
            if not ready:
                if process.poll() is not None:
                    # A closed process can leave a final readable event queued;
                    # the next select drains it before unregistering at EOF.
                    continue
                continue
            for key, _ in ready:
                stream = key.fileobj
                counter = key.data
                try:
                    chunk = os.read(stream.fileno(), 65_536)
                except OSError:
                    chunk = b""
                if chunk:
                    counter.consume(chunk)
                else:
                    counter.finish()
                    selector.unregister(stream)
                    stream.close()
    finally:
        selector.close()
        for signum, handler in old_handlers.items():
            try:
                signal.signal(signum, handler)
            except (OSError, ValueError):
                pass

    # wait() is safe after the pipes have been drained and preserves the
    # child's native return code, including negative signal values.
    process.wait()
    metrics = {
        "stdout_bytes": counters["stdout"].byte_count,
        "stdout_lines": counters["stdout"].finish(),
        "stderr_bytes": counters["stderr"].byte_count,
        "stderr_lines": counters["stderr"].finish(),
    }
    metrics["total_bytes"] = metrics["stdout_bytes"] + metrics["stderr_bytes"]
    metrics["total_lines"] = metrics["stdout_lines"] + metrics["stderr_lines"]
    return metrics


def _child_exit_code(returncode: int) -> int:
    # Python's negative signal convention cannot be passed directly to
    # sys.exit without becoming a confusing 254/243 shell status.
    return 128 + (-returncode) if returncode < 0 else returncode


def _record_status(returncode: int) -> str:
    return "passed" if returncode == 0 else "failed"


def _validated_label(label: str) -> str:
    label = label.strip()
    if not label:
        raise ValueError("label must not be empty")
    if len(label) > 512:
        raise ValueError("label must be at most 512 characters")
    return label


def _record_entry(
    *,
    label: str,
    environment: str,
    status: str,
    exit_code: int,
    wall_seconds: float,
    metrics: Mapping[str, int],
    output_policy: str,
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "recorded_at": utc_timestamp(),
        "session": uuid.uuid4().hex,
        "label": _validated_label(label),
        "environment": environment,
        "status": status,
        "exit_code": exit_code,
        "wall_seconds": round(max(0.0, wall_seconds), 6),
        "stdout_lines": int(metrics["stdout_lines"]),
        "stdout_bytes": int(metrics["stdout_bytes"]),
        "stderr_lines": int(metrics["stderr_lines"]),
        "stderr_bytes": int(metrics["stderr_bytes"]),
        "total_lines": int(metrics["total_lines"]),
        "total_bytes": int(metrics["total_bytes"]),
        "output_policy": output_policy,
    }


def write_record(entry: Mapping[str, Any], directory: Path, *, retain_local: bool = False) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    final_path = directory / f"{entry['recorded_at'].replace(':', '').replace('+00:00', 'Z')}-{entry['session']}.jsonl"
    fd, temporary_name = tempfile.mkstemp(prefix=".output-profile-", suffix=".tmp", dir=directory)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as output:
            output.write(json.dumps(dict(entry), sort_keys=True, separators=(",", ":")) + "\n")
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary_path, 0o600)
        # Finalization and pruning share the same lock so concurrent handoffs
        # cannot remove a session that is still being finalized.
        lock_path = directory / ".output-profile.lock"
        with lock_path.open("a+", encoding="utf-8") as lock:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
            os.replace(temporary_path, final_path)
            if retain_local:
                jsonl_files = [path for path in directory.glob("*.jsonl") if path.is_file()]
                jsonl_files.sort(key=lambda path: (path.stat().st_mtime_ns, path.name), reverse=True)
                for stale in jsonl_files[LOCAL_RETENTION:]:
                    try:
                        stale.unlink()
                    except FileNotFoundError:
                        pass
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
    finally:
        try:
            temporary_path.unlink()
        except FileNotFoundError:
            pass
    return final_path


def append_ci_summary(entry: Mapping[str, Any]) -> None:
    summary_name = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_name:
        return
    summary_path = Path(summary_name)
    try:
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        with summary_path.open("a", encoding="utf-8") as summary:
            summary.write(
                f"Output profile: `{entry['label']}` — {entry['status']}; "
                f"{entry['total_lines']} lines / {entry['total_bytes']} bytes.\n"
            )
    except OSError:
        # A reporting artifact must never change a verification result.
        pass


def run_command(
    command: Sequence[str],
    *,
    label: str,
    policy: str,
    environment: str,
    directory: Path | None = None,
) -> int:
    if os.environ.get("TRINKET_OUTPUT_PROFILE") == "0":
        try:
            return subprocess.call(list(command))
        except OSError as error:
            print(f"output-profile: unable to run child: {error}", file=sys.stderr)
            return 127

    started = time.monotonic()
    metrics = {key: 0 for key in ("stdout_lines", "stdout_bytes", "stderr_lines", "stderr_bytes", "total_lines", "total_bytes")}
    try:
        process = subprocess.Popen(list(command), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        metrics = _stream_process(process)
        native_code = process.returncode
    except OSError as error:
        print(f"output-profile: unable to run child: {error}", file=sys.stderr)
        native_code = 127
    wall_seconds = time.monotonic() - started
    entry = _record_entry(
        label=label,
        environment=environment,
        status=_record_status(native_code),
        exit_code=native_code,
        wall_seconds=wall_seconds,
        metrics=metrics,
        output_policy=policy,
    )
    try:
        output_directory = directory or profile_directory()
        write_record(entry, output_directory, retain_local=environment == "local")
        if environment == "ci":
            append_ci_summary(entry)
    except OSError as error:
        # Profiling is advisory: a read-only or unavailable artifact directory
        # must not turn a passing verification into a failure.
        print(f"output-profile: unable to write metadata: {error}", file=sys.stderr)
    return _child_exit_code(native_code)


def _record_is_valid(entry: Any) -> bool:
    if not isinstance(entry, dict) or entry.get("schema_version") != SCHEMA_VERSION:
        return False
    if not isinstance(entry.get("label"), str) or not entry["label"]:
        return False
    if entry.get("environment") not in {"local", "ci"}:
        return False
    if entry.get("status") not in {"passed", "failed"}:
        return False
    if not isinstance(entry.get("output_policy"), str) or not entry["output_policy"]:
        return False
    if not isinstance(entry.get("session"), str) or not entry["session"]:
        return False
    if not isinstance(entry.get("recorded_at"), str) or not entry["recorded_at"]:
        return False
    if not isinstance(entry.get("exit_code"), int) or isinstance(entry["exit_code"], bool):
        return False
    if (
        not isinstance(entry.get("wall_seconds"), (int, float))
        or isinstance(entry["wall_seconds"], bool)
        or not math.isfinite(float(entry["wall_seconds"]))
        or entry["wall_seconds"] < 0
    ):
        return False
    metric_keys = (
        "stdout_lines",
        "stdout_bytes",
        "stderr_lines",
        "stderr_bytes",
        "total_lines",
        "total_bytes",
    )
    if any(not isinstance(entry.get(key), int) or isinstance(entry[key], bool) or entry[key] < 0 for key in metric_keys):
        return False
    return True


def load_records(directories: Iterable[Path], environment: str | None = None) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    seen_paths: set[Path] = set()
    for directory in directories:
        if not directory.exists() or not directory.is_dir():
            continue
        for path in sorted(directory.rglob("*.jsonl")):
            if path in seen_paths:
                continue
            seen_paths.add(path)
            try:
                with path.open("r", encoding="utf-8") as source:
                    for raw in source:
                        try:
                            candidate = json.loads(raw)
                        except (json.JSONDecodeError, TypeError):
                            continue
                        if _record_is_valid(candidate) and (environment is None or candidate["environment"] == environment):
                            records.append(candidate)
            except OSError:
                continue
    records.sort(key=lambda entry: (entry["recorded_at"], entry["session"]))
    return records


def _over_budget(entry: Mapping[str, Any]) -> bool:
    return entry["total_lines"] > LINE_BUDGET or entry["total_bytes"] > BYTE_BUDGET


def _bucket(entry: Mapping[str, Any]) -> str:
    return "passed" if entry["status"] == "passed" or entry.get("exit_code") == 0 else "failed"


def _median(values: Sequence[int]) -> float:
    return float(statistics.median(values)) if values else 0.0


def action_reasons(history: Sequence[Mapping[str, Any]], index: int) -> list[str]:
    current = history[index]
    reasons: list[str] = []
    if _over_budget(current):
        reasons.append("budget")
    previous = list(history[max(0, index - TREND_SAMPLE_COUNT) : index])
    if len(previous) >= TREND_SAMPLE_COUNT:
        line_median = _median([entry["total_lines"] for entry in previous])
        byte_median = _median([entry["total_bytes"] for entry in previous])
        line_trend = (
            current["total_lines"] >= line_median * TREND_RATIO
            and current["total_lines"] - line_median >= TREND_LINE_DELTA
        )
        byte_trend = (
            current["total_bytes"] >= byte_median * TREND_RATIO
            and current["total_bytes"] - byte_median >= TREND_BYTE_DELTA
        )
        if line_trend or byte_trend:
            reasons.append("trend")
    recent = list(history[max(0, index - RECURRING_SAMPLE_COUNT + 1) : index + 1])
    if len(recent) >= RECURRING_SAMPLE_COUNT and sum(_over_budget(entry) for entry in recent) >= RECURRING_MINIMUM:
        reasons.append("recurring")
    return reasons


def _group_records(records: Sequence[Mapping[str, Any]]) -> dict[tuple[str, str], list[dict[str, Any]]]:
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for record in records:
        key = (record["label"], _bucket(record))
        grouped.setdefault(key, []).append(dict(record))
    for history in grouped.values():
        history.sort(key=lambda entry: (entry["recorded_at"], entry["session"]))
    return grouped


def _ranked_rows(records: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for (label, bucket), history in _group_records(records).items():
        latest = history[-1]
        reasons = action_reasons(history, len(history) - 1)
        excess = sum(
            max(0, entry["total_lines"] - LINE_BUDGET) + max(0, entry["total_bytes"] - BYTE_BUDGET)
            for entry in history
        )
        recurring = sum(_over_budget(entry) for entry in history[-RECURRING_SAMPLE_COUNT:])
        recurring_excess = sum(
            max(0, entry["total_lines"] - LINE_BUDGET) + max(0, entry["total_bytes"] - BYTE_BUDGET)
            for entry in history[-RECURRING_SAMPLE_COUNT:]
        )
        rows.append(
            {
                "label": label,
                "bucket": bucket,
                "history": history,
                "latest": latest,
                "reasons": reasons,
                "excess": excess,
                "recurring": recurring,
                "recurring_excess": recurring_excess,
                "max_bytes": max(entry["total_bytes"] for entry in history),
                "max_lines": max(entry["total_lines"] for entry in history),
            }
        )
    rows.sort(
        key=lambda row: (
            row["recurring_excess"],
            row["max_bytes"],
            row["max_lines"],
            row["excess"],
            row["label"],
        ),
        reverse=True,
    )
    return rows


def _format_bytes(value: int) -> str:
    if value < 1024:
        return f"{value} B"
    if value < 1024 * 1024:
        return f"{value / 1024:.1f} KB"
    return f"{value / (1024 * 1024):.1f} MB"


def render_report(
    records: Sequence[Mapping[str, Any]],
    *,
    actionable: bool,
    top: int,
    since: _datetime.datetime | None = None,
) -> str:
    rows = _ranked_rows(records)
    if since is not None:
        rows = [
            row
            for row in rows
            if _record_timestamp(row["latest"]) is not None
            and _record_timestamp(row["latest"]) >= since
        ]
    if actionable:
        rows = [row for row in rows if row["reasons"]][:top]
        if not rows:
            return ""
        lines = ["Actionable output hotspots:"]
        for row in rows:
            current = row["latest"]
            previous = row["history"][-2] if len(row["history"]) > 1 else None
            prior_text = ""
            if previous is not None:
                prior_text = f"; previous {previous['total_lines']} lines / {_format_bytes(previous['total_bytes'])}"
            reasons = ", ".join(row["reasons"])
            lines.append(
                f"- {row['label']} [{row['bucket']}]: {current['total_lines']} lines / "
                f"{_format_bytes(current['total_bytes'])}{prior_text} ({reasons})"
            )
        lines.append("Report: python3 Scripts/output-profile.py report --local --actionable")
        return "\n".join(lines) + "\n"

    lines = [f"Output profile: {len(records)} valid samples, {len(rows)} label/status groups"]
    for row in rows[:top]:
        latest = row["latest"]
        lines.append(
            f"- {row['label']} [{row['bucket']}]: {len(row['history'])} samples; "
            f"latest {latest['total_lines']} lines / {_format_bytes(latest['total_bytes'])}; "
            f"max {row['max_lines']} lines / {_format_bytes(row['max_bytes'])}"
        )
    return "\n".join(lines) + "\n"


def _append_report_summary(text: str) -> None:
    summary_name = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_name or not text:
        return
    try:
        with Path(summary_name).open("a", encoding="utf-8") as summary:
            first_line = text.splitlines()[0]
            summary.write(first_line + "\n")
    except OSError:
        pass


def _record_timestamp(entry: Mapping[str, Any]) -> _datetime.datetime | None:
    try:
        return parse_iso_timestamp(str(entry["recorded_at"]))
    except (KeyError, TypeError, ValueError):
        return None


def command_run(arguments: argparse.Namespace) -> int:
    label = _validated_label(arguments.label)
    policy = arguments.policy.strip()
    if not policy:
        raise ValueError("policy must not be empty")
    command = list(arguments.command)
    if command and command[0] == "--":
        command.pop(0)
    if not command:
        raise ValueError("run requires a command after --")
    return run_command(
        command,
        label=label,
        policy=policy,
        environment=infer_environment(arguments.environment),
    )


def command_report(arguments: argparse.Namespace) -> int:
    if arguments.ci is not None:
        directories = [Path(path).expanduser() for path in arguments.ci]
        environment = "ci"
    else:
        directories = [profile_directory()]
        environment = "local"
    records = load_records(directories, environment=environment)
    since = parse_iso_timestamp(arguments.since) if arguments.since is not None else None
    text = render_report(records, actionable=arguments.actionable, top=arguments.top, since=since)
    if text:
        print(text, end="")
        if environment == "ci":
            _append_report_summary(text)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    run_parser = subparsers.add_parser("run", help="run and profile a child command")
    run_parser.add_argument("--label", required=True)
    run_parser.add_argument("--policy", default="live")
    run_parser.add_argument("--environment", "--env", choices=("local", "ci"))
    run_parser.add_argument("command", nargs=argparse.REMAINDER)
    run_parser.set_defaults(handler=command_run)

    report_parser = subparsers.add_parser("report", help="report output metadata")
    selector = report_parser.add_mutually_exclusive_group()
    selector.add_argument("--local", action="store_true", help="read local history (default)")
    selector.add_argument("--ci", nargs="+", metavar="DIRECTORY", help="read CI artifact directories")
    report_parser.add_argument("--actionable", action="store_true")
    report_parser.add_argument("--top", type=_positive_integer, default=3)
    report_parser.add_argument("--since", metavar="ISO-8601")
    report_parser.set_defaults(handler=command_report)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    try:
        arguments = parser.parse_args(argv)
        return int(arguments.handler(arguments))
    except (ValueError, OSError) as error:
        print(f"output-profile: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
