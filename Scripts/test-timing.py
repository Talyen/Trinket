#!/usr/bin/env python3
"""Record and report test timing data without embedding Python in a shell runner."""

from __future__ import annotations

import json
import math
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def finite_nonnegative(value: object, label: str) -> float:
    if isinstance(value, bool):
        raise SystemExit(f"{label} must be a finite non-negative number")
    try:
        number = float(value)
    except (TypeError, ValueError):
        raise SystemExit(f"{label} must be a finite non-negative number")
    if not math.isfinite(number) or number < 0:
        raise SystemExit(f"{label} must be a finite non-negative number")
    return number


def valid_duration(value: object) -> bool:
    if value is None:
        return True
    if isinstance(value, bool):
        return False
    try:
        number = float(value)
    except (TypeError, ValueError):
        return False
    return math.isfinite(number) and number >= 0


def valid_entry(entry: object) -> bool:
    if not isinstance(entry, dict) or entry.get("schema_version", 1) != 1:
        return False
    if not isinstance(entry.get("mode"), str) or not entry["mode"]:
        return False
    if "run" in entry and (not isinstance(entry["run"], str) or not entry["run"]):
        return False
    summary = entry.get("summary")
    tests = entry.get("tests")
    if not isinstance(summary, dict) or not isinstance(tests, list):
        return False
    if not valid_duration(entry.get("wall_seconds")):
        return False
    if not valid_duration(summary.get("measured_test_seconds")):
        return False
    if "xcresult_seconds" in summary and not valid_duration(summary["xcresult_seconds"]):
        return False
    for key in ("passed", "failed", "skipped"):
        value = summary.get(key)
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            return False
    targets = entry.get("targets", [])
    if not isinstance(targets, list) or not all(isinstance(item, str) for item in targets):
        return False
    if "no_build" in entry and not isinstance(entry["no_build"], bool):
        return False
    return all(
        isinstance(test, dict)
        and isinstance(test.get("id"), str)
        and isinstance(test.get("name"), str)
        and test.get("seconds") is not None
        and valid_duration(test.get("seconds"))
        for test in tests
    )


def parse_xcresult(path: Path) -> dict:
    def read(kind: str) -> dict:
        raw = subprocess.check_output(
            ["xcrun", "xcresulttool", "get", "test-results", kind, "--path", str(path), "--format", "json"],
            text=True,
        )
        return json.loads(raw)

    summary = read("summary")
    payload = read("tests")
    tests: list[dict] = []

    def walk(nodes: object) -> None:
        if not isinstance(nodes, list):
            return
        for node in nodes:
            if not isinstance(node, dict):
                continue
            if node.get("nodeType") == "Test Case":
                tests.append(
                    {
                        "id": node.get("nodeIdentifier", node.get("name", "unknown")),
                        "name": node.get("name", ""),
                        "seconds": finite_nonnegative(node.get("durationInSeconds") or 0.0, "xcresult test duration"),
                        "result": node.get("result", "Unknown"),
                    }
                )
            walk(node.get("children"))

    walk(payload.get("testNodes"))
    start = summary.get("startTime")
    finish = summary.get("finishTime")
    xcresult_seconds = None
    if isinstance(start, (int, float)) and isinstance(finish, (int, float)):
        xcresult_seconds = finite_nonnegative(float(finish) - float(start), "xcresult duration")
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


def load_entries(log_path: Path) -> list[dict]:
    if not log_path.exists():
        return []
    entries: list[dict] = []
    for line in log_path.read_text(encoding="utf-8").splitlines():
        try:
            candidate = json.loads(line)
        except (json.JSONDecodeError, TypeError, ValueError):
            continue
        if valid_entry(candidate):
            entries.append(candidate)
    return entries


def append_entry(results_dir: Path, log_path: Path, entry: dict) -> None:
    entry["schema_version"] = 1
    if not valid_entry(entry):
        raise SystemExit("refusing to record malformed timing entry")
    results_dir.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, separators=(",", ":")) + "\n")
    raw_maximum = os.environ.get("TRINKET_KEEP_TIMING_HISTORY", "50")
    try:
        maximum = int(raw_maximum)
    except ValueError:
        raise SystemExit(f"TRINKET_KEEP_TIMING_HISTORY must be an integer, got {raw_maximum!r}")
    maximum = max(maximum, 1)
    entries = log_path.read_text(encoding="utf-8").splitlines()
    if len(entries) > maximum:
        log_path.write_text("\n".join(entries[-maximum:]) + "\n", encoding="utf-8")


def parse_options(args: list[str]) -> dict:
    values: dict = {"targets": []}
    index = 0
    while index < len(args):
        token = args[index]
        if token in {"--mode", "--run", "--wall", "--xcresult", "--max-wall"}:
            if index + 1 >= len(args):
                label = token.lstrip("-")
                raise SystemExit(f"{token} requires a finite non-negative number" if label in {"wall", "max-wall"} else f"{token} requires a value")
            values[token[2:].replace("-", "_")] = args[index + 1]
            index += 2
        elif token in {"--no-xcresult", "--no-build", "--skip-if-missing", "--by-class"}:
            values[token[2:].replace("-", "_")] = True
            index += 1
        elif token in {"--last", "--top"}:
            label = "positive" if token == "--last" else "non-negative"
            if index + 1 >= len(args):
                raise SystemExit(f"{token} must be a {label} integer")
            try:
                number = int(args[index + 1])
            except ValueError:
                raise SystemExit(f"{token} must be a {label} integer")
            if (token == "--last" and number < 1) or (token == "--top" and number < 0):
                raise SystemExit(f"{token} must be a {label} integer")
            values[token[2:]] = number
            index += 2
        elif token.startswith("-"):
            raise SystemExit(f"unknown option: {token}")
        else:
            values["targets"].append(token)
            index += 1
    return values


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
        parsed = parse_xcresult(path)
        recorded_xcresult = str(path)
    append_entry(results_dir, log_path, {"recorded_at": datetime.now(timezone.utc).isoformat(), "run": run, "mode": mode, "targets": values["targets"], "no_build": bool(values.get("no_build")), "wall_seconds": wall_seconds, "xcresult": recorded_xcresult, **parsed})
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


def median(values: list[float]) -> float:
    ordered = sorted(values)
    if not ordered:
        return 0.0
    middle = len(ordered) // 2
    return ordered[middle] if len(ordered) % 2 else (ordered[middle - 1] + ordered[middle]) / 2


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
    entries = load_entries(log_path)
    mode = values.get("mode")
    if mode:
        entries = [entry for entry in entries if entry.get("mode") == mode]
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
    entries = load_entries(log_path)
    mode = values.get("mode")
    if mode:
        entries = [entry for entry in entries if entry.get("mode") == mode]
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
        for identifier, seconds in aggregate.items():
            if "/" in identifier:
                classes.setdefault(identifier.split("/", 1)[0], []).extend(seconds)
        print(f"\nSlow classes (by total logged duration across {len(entries)} runs)\n────────────────────────────────────────────────────────────────────────────")
        print(f"{'Total':>8} {'Median':>8} {'Tests':>5}  Class")
        for name, seconds in sorted(classes.items(), key=lambda item: sum(item[1]), reverse=True):
            print(f"{format_seconds(sum(seconds)):>8} {format_seconds(median(seconds)):>8} {len(seconds):>5}  {name}")


def assert_budget(log_path: Path, args: list[str]) -> None:
    values = parse_options(args)
    mode = values.get("mode", "")
    maximum = values.get("max_wall")
    if not mode or maximum is None:
        raise SystemExit("assert-budget requires --mode and --max-wall")
    maximum_seconds = finite_nonnegative(maximum, "--max-wall")
    entries = [entry for entry in load_entries(log_path) if entry.get("mode") == mode]
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
        print("Usage: test-timing.sh [show|report|record|assert-budget] ...")
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
