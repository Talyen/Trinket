#!/usr/bin/env python3
"""Record and report test timing data without embedding Python in a shell runner."""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import subprocess
import sys
from statistics import median
from datetime import datetime, timezone
from internal.output_retention import read_timing, update_timing
from pathlib import Path

from internal.diagnostics.xcresult_diagnostics import run_xcresulttool, walk_test_nodes


def duration_number(value: object) -> float:
    if isinstance(value, bool):
        raise ValueError("boolean duration")
    number = float(value)
    if not math.isfinite(number) or number < 0:
        raise ValueError("invalid duration")
    return number


def finite_nonnegative(value: object, label: str) -> float:
    try:
        return duration_number(value)
    except (TypeError, ValueError, OverflowError):
        raise SystemExit(f"{label} must be a finite non-negative number")


def valid_entry(entry: object) -> bool:
    if not isinstance(entry, dict) or type(entry.get("schema_version", 1)) is not int or entry.get("schema_version", 1) != 1:
        return False
    if not isinstance(entry.get("mode"), str) or not entry["mode"]:
        return False
    if "run" in entry and (not isinstance(entry["run"], str) or not entry["run"]):
        return False
    if any(key in entry and not isinstance(entry[key], str) for key in ("recorded_at", "xcresult")):
        return False
    summary = entry.get("summary")
    tests = entry.get("tests")
    if not isinstance(summary, dict) or not isinstance(tests, list):
        return False
    try:
        for value in (entry.get("wall_seconds"), summary.get("measured_test_seconds"),
                      summary.get("xcresult_seconds")):
            if value is not None:
                duration_number(value)
        for test in tests:
            if not isinstance(test, dict) or not isinstance(test.get("id"), str) or not isinstance(test.get("name"), str):
                return False
            duration_number(test.get("seconds"))
    except (TypeError, ValueError, OverflowError):
        return False
    for key in ("passed", "failed", "skipped"):
        value = summary.get(key)
        if type(value) is not int or value < 0:
            return False
    targets = entry.get("targets", [])
    if not isinstance(targets, list) or not all(isinstance(item, str) for item in targets):
        return False
    if "no_build" in entry and not isinstance(entry["no_build"], bool):
        return False
    return True


def parse_xcresult(path: Path, manifest: dict | None = None) -> dict:
    def read(kind: str) -> dict:
        payload, error = run_xcresulttool(path, ["get", "test-results", kind])
        if not isinstance(payload, dict):
            raise SystemExit(error or f"xcresult {kind} is not an object")
        return payload

    summary = None
    try:
        if (isinstance(manifest, dict) and type(manifest.get("schema_version")) is int
                and manifest["schema_version"] == 1
                and manifest.get("action") in {"test", "test-without-building"}
                and manifest.get("result_bundle_complete") is True
                and Path(manifest["result_bundle"]).resolve() == path.resolve()
                and isinstance(manifest.get("test_summary"), dict)):
            summary = manifest["test_summary"]
    except (OSError, ValueError, KeyError, TypeError):
        pass  # Missing/legacy/mismatched evidence uses a fresh export.
    if summary is None:
        summary = read("summary")
    payload = read("tests")
    tests = [
        {"id": node.get("nodeIdentifier", node.get("name", "unknown")),
         "name": node.get("name", ""),
         "seconds": finite_nonnegative(node.get("durationInSeconds", 0.0), "xcresult test duration"),
         "result": node.get("result", "Unknown"),
         "arguments": [child.get("result", "Unknown") for child in walk_test_nodes(node.get("children"))
                       if child.get("nodeType") == "Arguments"]}
        for node in walk_test_nodes(payload.get("testNodes")) if node.get("nodeType") == "Test Case"
    ]
    start = summary.get("startTime")
    finish = summary.get("finishTime")
    xcresult_seconds = None
    if start is not None and finish is not None:
        xcresult_seconds = finite_nonnegative(
            finite_nonnegative(finish, "xcresult finish") - finite_nonnegative(start, "xcresult start"),
            "xcresult duration",
        )
    return {
        "summary": {
            "passed": summary.get("passedTests", 0),
            "failed": summary.get("failedTests", 0),
            "skipped": summary.get("skippedTests", 0),
            "result": summary.get("result", "Unknown"),
            "xcresult_seconds": xcresult_seconds,
            "measured_test_seconds": sum(test["seconds"] for test in tests),
        },
        "tests": tests,
    }


def load_entries(log_path: Path, mode: str | None = None) -> list[dict]:
    if not log_path.exists():
        return []
    entries: list[dict] = []
    for line in read_timing(log_path):
        try:
            candidate = json.loads(line)
        except (json.JSONDecodeError, TypeError, ValueError):
            continue
        if valid_entry(candidate) and (not mode or candidate['mode'] == mode):
            entries.append(candidate)
    return entries


def append_entry(results_dir: Path, log_path: Path, entry: dict) -> None:
    raw_maximum = os.environ.get("TRINKET_KEEP_TIMING_HISTORY", "50")
    try:
        maximum = max(int(raw_maximum), 1)
    except ValueError:
        raise SystemExit(f"TRINKET_KEEP_TIMING_HISTORY must be an integer, got {raw_maximum!r}")
    entry["schema_version"] = 1
    if not valid_entry(entry):
        raise SystemExit("refusing to record malformed timing entry")
    results_dir.mkdir(parents=True, exist_ok=True)
    update_timing(log_path, entry=entry, maximum=maximum)


def parse_options(args: list[str]) -> dict:
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False,
                                     argument_default=argparse.SUPPRESS)
    for option in ("--mode", "--run", "--wall", "--xcresult", "--max-wall", "--manifest"):
        parser.add_argument(option)
    for option in ("--no-xcresult", "--no-build", "--skip-if-missing", "--by-class"):
        parser.add_argument(option, action="store_true")
    parser.add_argument("--last", type=int)
    parser.add_argument("--top", type=int)
    parser.add_argument("targets", nargs="*", default=[])
    values = vars(parser.parse_intermixed_args(args))
    for key, minimum in (("last", 1), ("top", 0)):
        if key in values and values[key] < minimum:
            parser.error(f"--{key} must be {'positive' if minimum else 'non-negative'}")
    return values


def current_commit() -> str | None:
    try:
        value = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True, stderr=subprocess.DEVNULL, timeout=5).strip()
        return value if re.fullmatch('[0-9a-f]{40}', value) else None
    except (OSError, subprocess.SubprocessError):
        return None


def record(results_dir: Path, log_path: Path, args: list[str]) -> None:
    values = parse_options(args)
    mode = values.get("mode", "")
    if not mode:
        raise SystemExit("record requires --mode")
    run = values.get("run", "")
    if not run:
        raise SystemExit("record requires --run")
    wall = values.get("wall")
    wall_seconds = finite_nonnegative(wall, "--wall") if wall is not None else None
    xcresult = values.get("xcresult", "")
    no_xcresult = bool(values.get("no_xcresult"))
    if (not xcresult and not no_xcresult) or (xcresult and no_xcresult):
        raise SystemExit("record requires exactly one of --xcresult or --no-xcresult")
    if no_xcresult:
        if wall_seconds is None:
            raise SystemExit("--no-xcresult requires --wall")
        parsed = {"summary": {"passed": 0, "failed": 0, "skipped": 0, "result": "wall-only", "xcresult_seconds": None, "measured_test_seconds": 0.0}, "tests": []}
        recorded_xcresult = ""
    else:
        path = Path(xcresult)
        if not path.exists():
            raise SystemExit(f"xcresult not found: {path}")
        if not (path / "Info.plist").is_file():
            raise SystemExit(f"xcresult is incomplete: {path}")
        manifest = None
        if values.get("manifest"):
            try:
                manifest = json.loads(Path(values["manifest"]).read_text())
            except (OSError, ValueError):
                pass
        parsed = parse_xcresult(path, manifest)
        recorded_xcresult = str(path)
    append_entry(results_dir, log_path, {"recorded_at": datetime.now(timezone.utc).isoformat(), "commit": current_commit(), "run": run, "mode": mode, "targets": values["targets"], "no_build": bool(values.get("no_build")), "wall_seconds": wall_seconds, "xcresult": recorded_xcresult, **parsed})
    # Quiet test runs print nothing on success; this single line is the
    # terminal-visible proof that tests executed and their outcome.
    summary = parsed["summary"]
    if summary.get("result") == "wall-only":
        print(f"{mode} — wall-only timing {format_seconds(wall_seconds)} (run {run})")
    else:
        wall_note = f" (wall {format_seconds(wall_seconds)})" if wall_seconds is not None else ""
        print(
            f"{mode} — {summary.get('passed', 0)} passed, {summary.get('failed', 0)} failed, "
            f"{summary.get('skipped', 0)} skipped in {format_seconds(summary.get('xcresult_seconds'))}{wall_note} "
            f"(run {run})"
        )


def format_seconds(seconds: object) -> str:
    if seconds is None:
        return "—"
    value = float(seconds)
    if value < 60:
        return f"{value:.1f}s"
    minutes, remainder = divmod(value, 60)
    return f"{int(minutes)}m {remainder:.0f}s"


def entry_run(entry: dict) -> str:
    run = entry.get("run")
    if isinstance(run, str) and run:
        return run
    xcresult = entry.get("xcresult")
    if isinstance(xcresult, str) and xcresult:
        return Path(xcresult).stem
    return "unknown"


def xcresult_state(entry: dict) -> str:
    xcresult = entry.get("xcresult")
    if not isinstance(xcresult, str) or not xcresult:
        return "(not recorded/incomplete)"
    return "(available)" if Path(xcresult).exists() else "(pruned)"


def show(log_path: Path, args: list[str]) -> None:
    values = parse_options(args)
    entries = load_entries(log_path, values.get("mode"))
    if not entries:
        print(f"No timing entries in {log_path}")
        return
    recent = entries[-values.get("last", 10):]
    for entry in recent:
        summary = entry.get("summary", {})
        targets = ", ".join(entry.get("targets") or []) or "—"
        when = entry.get("recorded_at", "")
        counts = f"{summary.get('passed', 0)} passed, {summary.get('failed', 0)} failed, {summary.get('skipped', 0)} skipped"
        print(
            f"{when} | {entry_run(entry)} | {entry.get('mode', '?')} | "
            f"{summary.get('result', 'Unknown')} | {counts} | wall {format_seconds(entry.get('wall_seconds'))} | "
            f"xcresult {xcresult_state(entry)} | {targets}"
        )


def report(log_path: Path, args: list[str]) -> None:
    values = parse_options(args)
    entries = load_entries(log_path, values.get("mode"))
    if not entries:
        print(f"No timing entries in {log_path}")
        print("Run ./Scripts/test.sh to populate the log.")
        return
    last = values.get("last", 15)
    top = values.get("top", 20)
    recent = entries[-last:]
    print(f"Timing log: {log_path}")
    print(f"Entries: {len(entries)} total, showing last {len(recent)}\n")
    print("Recent runs\n───────────")
    print(f"{'When':<20} {'Mode':<12} {'Wall':>8} {'Tests':>8} {'Pass':>6} {'Build':>7}  Targets")
    for entry in recent:
        when = entry.get("recorded_at", "")[:19].replace("T", " ")
        summary = entry.get("summary", {})
        build = "no" if entry.get("no_build") else "yes"
        targets = ", ".join(entry.get("targets") or []) or "—"
        print(f"{when:<20} {entry.get('mode', '?'):<12} {format_seconds(entry.get('wall_seconds')):>8} {len(entry.get('tests', [])):>8} {summary.get('passed', 0):>6} {build:>7}  {targets}")
    aggregate: dict[str, list[float]] = {}
    for entry in entries:
        for test in entry.get("tests", []):
            identifier = test.get("id") or test.get("name")
            if identifier:
                aggregate.setdefault(identifier, []).append(float(test.get("seconds") or 0))
    ranked = sorted(aggregate.items(), key=lambda item: max(item[1]), reverse=True)[:top]
    print(f"\nSlow-test hotspots (top {len(ranked)} by max duration across all logged runs)\n────────────────────────────────────────────────────────────────────────────")
    print(f"{'Max':>8} {'Median':>8} {'Runs':>5}  Test")
    for identifier, seconds in ranked:
        print(f"{format_seconds(max(seconds)):>8} {format_seconds(median(seconds)):>8} {len(seconds):>5}  {identifier}")
    if values.get("by_class"):
        classes: dict[str, list[float]] = {}
        for entry in entries:
            totals: dict[str, float] = {}
            for test in entry["tests"]:
                identifier = test["id"] or test["name"]
                if "/" in identifier:
                    name = identifier.split("/", 1)[0]
                    totals[name] = totals.get(name, 0) + float(test["seconds"])
            for name, seconds in totals.items():
                classes.setdefault(name, []).append(seconds)
        print(f"\nSlow classes (summed test durations per invocation, across {len(entries)} runs; not wall time)\n────────────────────────────────────────────────────────────────────────────")
        print(f"{'Total':>8} {'Median':>8} {'Runs':>5}  Class")
        for name, seconds in sorted(classes.items(), key=lambda item: sum(item[1]), reverse=True):
            print(f"{format_seconds(sum(seconds)):>8} {format_seconds(median(seconds)):>8} {len(seconds):>5}  {name}")


def assert_budget(log_path: Path, args: list[str]) -> None:
    values = parse_options(args)
    mode = values.get("mode", "")
    maximum = values.get("max_wall")
    if not mode or maximum is None:
        raise SystemExit("assert-budget requires --mode and --max-wall")
    maximum_seconds = finite_nonnegative(maximum, "--max-wall")
    entries = load_entries(log_path, mode)
    if not entries:
        if values.get("skip_if_missing"):
            print(f"No timing entries for mode '{mode}'; skipping budget check.")
            return
        raise SystemExit(f"No timing entries for mode '{mode}' in {log_path}")
    latest = entries[-1]
    duration = latest.get("summary", {}).get("xcresult_seconds")
    source = "xcresult"
    if duration is None:
        duration = latest.get("wall_seconds")
        source = "wall"
    if duration is None:
        raise SystemExit(f"Latest '{mode}' timing entry has no measurable duration")
    duration = finite_nonnegative(duration, "latest duration")
    if duration > maximum_seconds:
        raise SystemExit(f"Timing budget exceeded for '{mode}': {format_seconds(duration)} ({source}) > {format_seconds(maximum_seconds)}")
    print(f"Timing budget OK for '{mode}': {format_seconds(duration)} ({source}) <= {format_seconds(maximum_seconds)}")


def main(argv: list[str]) -> int:
    results_dir = Path(os.environ.get("RESULTS_DIR", Path.cwd() / ".DerivedData/TestResults"))
    command = argv[0] if argv else "report"
    args = argv[1:] if argv else []
    if command in {"-h", "--help", "help"}:
        print("Usage: python3 Scripts/test-timing.py [show|report|record|assert-budget] ...")
        return 0
    if command not in {"show", "report", "record", "assert-budget"}:
        args = argv
        command = "report"
    log_path = results_dir / "timing-log.jsonl"
    handlers = {"show": show, "report": report, "record": record, "assert-budget": assert_budget}
    if command == "record":
        handlers[command](results_dir, log_path, args)
    else:
        handlers[command](log_path, args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
