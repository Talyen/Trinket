#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

RESULTS_DIR="${RESULTS_DIR:-$PWD/.DerivedData/TestResults}"
LOG_PATH="$RESULTS_DIR/timing-log.jsonl"
DEFAULT_LAST_RUNS=15
DEFAULT_TOP_TESTS=20

usage() {
  cat <<'EOF'
Usage:
  ./Scripts/test-timing.sh [report] [--mode MODE] [--last N] [--top N] [--by-class]
  ./Scripts/test-timing.sh record --mode MODE --wall SECONDS --xcresult PATH [--no-build] [TARGET ...]
  ./Scripts/test-timing.sh ingest MODE [--wall SECONDS]
  ./Scripts/test-timing.sh assert-budget --mode MODE --max-wall SECONDS [--skip-if-missing]

Read per-run and per-test timings from the local JSONL log. No tests are executed.

  report         Show recent runs and slow-test hotspots (default command).
  record         Append one run to the log (called automatically by test.sh).
  ingest         Backfill the log from an existing .xcresult bundle on disk.
  assert-budget  Fail if the latest run for MODE exceeded the budget. Uses
                 xcresult test duration when available, otherwise wall clock.

Log file: .DerivedData/TestResults/timing-log.jsonl
EOF
}

run_python() {
  python3 - "$@" <<'PY'
import json
import math
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

command = sys.argv[1]
results_dir = Path(sys.argv[2])
log_path = results_dir / "timing-log.jsonl"


def finite_nonnegative(value, label: str) -> float:
    if isinstance(value, bool):
        raise SystemExit(f"{label} must be a finite non-negative number")
    try:
        number = float(value)
    except (TypeError, ValueError):
        raise SystemExit(f"{label} must be a finite non-negative number")
    if not math.isfinite(number) or number < 0:
        raise SystemExit(f"{label} must be a finite non-negative number")
    return number


def valid_duration(value) -> bool:
    if value is None:
        return True
    if isinstance(value, bool):
        return False
    try:
        number = float(value)
    except (TypeError, ValueError):
        return False
    return math.isfinite(number) and number >= 0


def valid_entry(entry) -> bool:
    if not isinstance(entry, dict):
        return False
    schema_version = entry.get("schema_version", 1)
    if (
        not isinstance(schema_version, int)
        or isinstance(schema_version, bool)
        or schema_version != 1
    ):
        return False
    if not isinstance(entry.get("mode"), str) or not entry["mode"]:
        return False
    if not isinstance(entry.get("summary"), dict) or not isinstance(entry.get("tests"), list):
        return False
    if not valid_duration(entry.get("wall_seconds")):
        return False
    summary = entry["summary"]
    if "measured_test_seconds" not in summary:
        return False
    if not valid_duration(summary["measured_test_seconds"]):
        return False
    if "xcresult_seconds" in summary and not valid_duration(summary["xcresult_seconds"]):
        return False
    for key in ("passed", "failed", "skipped"):
        if key not in summary:
            return False
        value = summary[key]
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            return False
    targets = entry.get("targets", [])
    if not isinstance(targets, list) or not all(isinstance(target, str) for target in targets):
        return False
    if "no_build" in entry and not isinstance(entry["no_build"], bool):
        return False
    for test in entry["tests"]:
        if not isinstance(test, dict):
            return False
        if not isinstance(test.get("id"), str) or not isinstance(test.get("name"), str):
            return False
        if "seconds" not in test or test["seconds"] is None:
            return False
        if not valid_duration(test["seconds"]):
            return False
    return True


def parse_xcresult(xcresult_path: Path) -> dict:
    summary = json.loads(
        subprocess.check_output(
            [
                "xcrun",
                "xcresulttool",
                "get",
                "test-results",
                "summary",
                "--path",
                str(xcresult_path),
                "--format",
                "json",
            ]
        )
    )
    tests_payload = json.loads(
        subprocess.check_output(
            [
                "xcrun",
                "xcresulttool",
                "get",
                "test-results",
                "tests",
                "--path",
                str(xcresult_path),
                "--format",
                "json",
            ]
        )
    )

    tests = []

    def walk(nodes):
        for node in nodes or []:
            if node.get("nodeType") == "Test Case":
                tests.append(
                    {
                        "id": node.get("nodeIdentifier", node.get("name", "unknown")),
                        "name": node.get("name", ""),
                        "seconds": finite_nonnegative(
                            node.get("durationInSeconds") or 0.0,
                            "xcresult test duration",
                        ),
                        "result": node.get("result", "Unknown"),
                    }
                )
            walk(node.get("children"))

    walk(tests_payload.get("testNodes"))

    start_time = summary.get("startTime")
    finish_time = summary.get("finishTime")
    measured_test_seconds = sum(test["seconds"] for test in tests)
    xcresult_seconds = None
    if isinstance(start_time, (int, float)) and isinstance(finish_time, (int, float)):
        xcresult_seconds = finite_nonnegative(
            float(finish_time) - float(start_time),
            "xcresult duration",
        )

    return {
        "summary": {
            "passed": summary.get("passedTests", 0),
            "failed": summary.get("failedTests", 0),
            "skipped": summary.get("skippedTests", 0),
            "result": summary.get("result", "Unknown"),
            "xcresult_seconds": xcresult_seconds,
            "measured_test_seconds": measured_test_seconds,
        },
        "tests": tests,
    }


def append_entry(entry: dict) -> None:
    entry["schema_version"] = 1
    if not valid_entry(entry):
        raise SystemExit("refusing to record malformed timing entry")
    results_dir.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, separators=(",", ":")))
        handle.write("\n")

    max_entries = 250
    lines = log_path.read_text(encoding="utf-8").splitlines()
    if len(lines) > max_entries:
        log_path.write_text("\n".join(lines[-max_entries:]) + "\n", encoding="utf-8")


def load_entries() -> list[dict]:
    if not log_path.exists():
        return []

    entries = []
    for line in log_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except (json.JSONDecodeError, TypeError, ValueError):
            continue
        if valid_entry(entry):
            entries.append(entry)
    return entries


def format_seconds(seconds: Optional[float]) -> str:
    if seconds is None:
        return "—"
    if seconds < 60:
        return f"{seconds:.1f}s"
    minutes = int(seconds // 60)
    remainder = seconds - (minutes * 60)
    return f"{minutes}m {remainder:.0f}s"


def median(values: list[float]) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    mid = len(ordered) // 2
    if len(ordered) % 2 == 1:
        return ordered[mid]
    return (ordered[mid - 1] + ordered[mid]) / 2.0


def cmd_record(args: list[str]) -> None:
    mode = ""
    wall_seconds = None
    xcresult = ""
    no_build = False
    targets: list[str] = []

    index = 0
    while index < len(args):
        token = args[index]
        if token == "--mode" and index + 1 < len(args):
            mode = args[index + 1]
            index += 2
            continue
        if token == "--wall":
            if index + 1 >= len(args):
                raise SystemExit("--wall requires a finite non-negative number")
            wall_seconds = finite_nonnegative(args[index + 1], "--wall")
            index += 2
            continue
        if token == "--xcresult" and index + 1 < len(args):
            xcresult = args[index + 1]
            index += 2
            continue
        if token == "--no-build":
            no_build = True
            index += 1
            continue
        if token.startswith("-"):
            raise SystemExit(f"unknown option: {token}")
        targets.append(token)
        index += 1

    if not mode or not xcresult:
        raise SystemExit("record requires --mode and --xcresult")

    xcresult_path = Path(xcresult)
    if not xcresult_path.exists():
        raise SystemExit(f"xcresult not found: {xcresult_path}")

    parsed = parse_xcresult(xcresult_path)
    entry = {
        "recorded_at": datetime.now(timezone.utc).isoformat(),
        "mode": mode,
        "targets": targets,
        "no_build": no_build,
        "wall_seconds": wall_seconds,
        "xcresult": str(xcresult_path),
        **parsed,
    }
    append_entry(entry)


def cmd_ingest(args: list[str]) -> None:
    if not args:
        raise SystemExit("ingest requires MODE (unit, smoke, smoke-full, ui, all)")

    mode = args[0]
    wall_seconds = None
    if len(args) >= 2 and args[1] == "--wall":
        if len(args) < 3:
            raise SystemExit("--wall requires a finite non-negative number")
        wall_seconds = finite_nonnegative(args[2], "--wall")
        if len(args) > 3:
            raise SystemExit(f"unknown option: {args[3]}")
    elif len(args) > 1:
        raise SystemExit(f"unknown option: {args[1]}")

    xcresult_path = results_dir / f"{mode}.xcresult"
    if not xcresult_path.exists():
        raise SystemExit(f"xcresult not found: {xcresult_path}")

    parsed = parse_xcresult(xcresult_path)
    entry = {
        "recorded_at": datetime.fromtimestamp(
            xcresult_path.stat().st_mtime, tz=timezone.utc
        ).isoformat(),
        "mode": mode,
        "targets": [],
        "no_build": False,
        "wall_seconds": wall_seconds if wall_seconds is not None else parsed["summary"].get("xcresult_seconds"),
        "xcresult": str(xcresult_path),
        "ingested": True,
        **parsed,
    }
    append_entry(entry)


def cmd_report(args: list[str]) -> None:
    mode_filter = None
    last_runs = 15
    top_tests = 20
    by_class = False

    index = 0
    while index < len(args):
        token = args[index]
        if token == "--mode" and index + 1 < len(args):
            mode_filter = args[index + 1]
            index += 2
            continue
        if token == "--last":
            if index + 1 >= len(args):
                raise SystemExit("--last must be a positive integer")
            try:
                last_runs = int(args[index + 1])
            except ValueError:
                raise SystemExit("--last must be a positive integer")
            if last_runs <= 0:
                raise SystemExit("--last must be a positive integer")
            index += 2
            continue
        if token == "--top":
            if index + 1 >= len(args):
                raise SystemExit("--top must be a non-negative integer")
            try:
                top_tests = int(args[index + 1])
            except ValueError:
                raise SystemExit("--top must be a non-negative integer")
            if top_tests < 0:
                raise SystemExit("--top must be a non-negative integer")
            index += 2
            continue
        if token == "--by-class":
            by_class = True
            index += 1
            continue
        if token.startswith("-"):
            raise SystemExit(f"unknown option: {token}")
        index += 1

    entries = load_entries()
    if mode_filter:
        entries = [entry for entry in entries if entry.get("mode") == mode_filter]

    if not entries:
        print(f"No timing entries in {log_path}")
        print("Run ./Scripts/test.sh or ./Scripts/test-timing.sh ingest <mode> to populate the log.")
        return

    recent = entries[-last_runs:]
    print(f"Timing log: {log_path}")
    print(f"Entries: {len(entries)} total, showing last {len(recent)}")
    print("")
    print("Recent runs")
    print("───────────")
    print(f"{'When':<20} {'Mode':<12} {'Wall':>8} {'Tests':>8} {'Pass':>6} {'Build':>7}  Targets")
    for entry in recent:
        when = entry.get("recorded_at", "")[:19].replace("T", " ")
        mode = entry.get("mode", "?")
        wall = format_seconds(entry.get("wall_seconds"))
        test_count = len(entry.get("tests", []))
        passed = entry.get("summary", {}).get("passed", 0)
        build = "no" if entry.get("no_build") else "yes"
        targets = ", ".join(entry.get("targets") or []) or "—"
        print(f"{when:<20} {mode:<12} {wall:>8} {test_count:>8} {passed:>6} {build:>7}  {targets}")

    aggregates: dict[str, dict] = {}
    for entry in entries:
        for test in entry.get("tests", []):
            test_id = test.get("id") or test.get("name")
            if not test_id:
                continue
            bucket = aggregates.setdefault(
                test_id,
                {
                    "id": test_id,
                    "name": test.get("name", ""),
                    "seconds": [],
                    "results": [],
                },
            )
            bucket["seconds"].append(float(test.get("seconds") or 0.0))
            bucket["results"].append(test.get("result", "Unknown"))

    ranked = sorted(
        aggregates.values(),
        key=lambda item: max(item["seconds"]) if item["seconds"] else 0.0,
        reverse=True,
    )[:top_tests]

    print("")
    print(f"Slow-test hotspots (top {len(ranked)} by max duration across all logged runs)")
    print("────────────────────────────────────────────────────────────────────────────")
    print(f"{'Max':>8} {'Median':>8} {'Runs':>5}  Test")
    for item in ranked:
        seconds = item["seconds"]
        print(
            f"{format_seconds(max(seconds)):>8} "
            f"{format_seconds(median(seconds)):>8} "
            f"{len(seconds):>5}  "
            f"{item['id']}"
        )

    if by_class:
        class_aggregates: dict[str, dict] = {}
        for entry in entries:
            for test in entry.get("tests", []):
                test_id = test.get("id") or test.get("name")
                if not test_id or "/" not in test_id:
                    continue
                class_name = test_id.split("/", 1)[0]
                bucket = class_aggregates.setdefault(
                    class_name,
                    {"class": class_name, "seconds": [], "tests": 0},
                )
                bucket["seconds"].append(float(test.get("seconds") or 0.0))
                bucket["tests"] += 1

        class_ranked = sorted(
            class_aggregates.values(),
            key=lambda item: sum(item["seconds"]),
            reverse=True,
        )

        print("")
        print(f"Slow classes (by total logged duration across {len(entries)} runs)")
        print("────────────────────────────────────────────────────────────────────────────")
        print(f"{'Total':>8} {'Median':>8} {'Tests':>5}  Class")
        for item in class_ranked:
            seconds = item["seconds"]
            print(
                f"{format_seconds(sum(seconds)):>8} "
                f"{format_seconds(median(seconds)):>8} "
                f"{item['tests']:>5}  "
                f"{item['class']}"
            )


def cmd_assert_budget(args: list[str]) -> None:
    mode = ""
    max_wall = None
    skip_if_missing = False

    index = 0
    while index < len(args):
        token = args[index]
        if token == "--mode" and index + 1 < len(args):
            mode = args[index + 1]
            index += 2
            continue
        if token == "--max-wall":
            if index + 1 >= len(args):
                raise SystemExit("--max-wall must be a finite non-negative number")
            max_wall = finite_nonnegative(args[index + 1], "--max-wall")
            index += 2
            continue
        if token == "--skip-if-missing":
            skip_if_missing = True
            index += 1
            continue
        if token.startswith("-"):
            raise SystemExit(f"unknown option: {token}")
        index += 1

    if not mode or max_wall is None:
        raise SystemExit("assert-budget requires --mode and --max-wall")

    entries = [entry for entry in load_entries() if entry.get("mode") == mode]
    if not entries:
        if skip_if_missing:
            print(f"No timing entries for mode '{mode}'; skipping budget check.")
            return
        raise SystemExit(f"No timing entries for mode '{mode}' in {log_path}")

    latest = entries[-1]
    duration_seconds = latest.get("summary", {}).get("xcresult_seconds")
    duration_source = "xcresult"
    if duration_seconds is None:
        duration_seconds = latest.get("wall_seconds")
        duration_source = "wall"

    if duration_seconds is None:
        raise SystemExit(f"Latest '{mode}' timing entry has no measurable duration")

    duration_seconds = finite_nonnegative(duration_seconds, "latest duration")
    if duration_seconds > max_wall:
        raise SystemExit(
            f"Timing budget exceeded for '{mode}': "
            f"{format_seconds(duration_seconds)} ({duration_source}) > "
            f"{format_seconds(max_wall)}"
        )

    print(
        f"Timing budget OK for '{mode}': "
        f"{format_seconds(duration_seconds)} ({duration_source}) <= "
        f"{format_seconds(max_wall)}"
    )


if command == "record":
    cmd_record(sys.argv[3:])
elif command == "ingest":
    cmd_ingest(sys.argv[3:])
elif command == "assert-budget":
    cmd_assert_budget(sys.argv[3:])
elif command == "report":
    cmd_report(sys.argv[3:])
else:
    raise SystemExit(f"unknown command: {command}")
PY
}

COMMAND="${1:-report}"
[[ $# -gt 0 ]] && shift

case "$COMMAND" in
  -h|--help|help)
    usage
    ;;
  record|ingest|report|assert-budget)
  run_python "$COMMAND" "$RESULTS_DIR" "$@"
    ;;
  *)
    run_python report "$RESULTS_DIR" "$COMMAND" "$@"
    ;;
esac
