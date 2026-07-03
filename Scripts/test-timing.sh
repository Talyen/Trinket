#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

RESULTS_DIR="$PWD/.DerivedData/TestResults"
LOG_PATH="$RESULTS_DIR/timing-log.jsonl"
DEFAULT_LAST_RUNS=15
DEFAULT_TOP_TESTS=20

usage() {
  cat <<'EOF'
Usage:
  ./Scripts/test-timing.sh [report] [--mode MODE] [--last N] [--top N]
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
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

command = sys.argv[1]
results_dir = Path(sys.argv[2])
log_path = results_dir / "timing-log.jsonl"


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
                        "seconds": float(node.get("durationInSeconds") or 0.0),
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
        xcresult_seconds = max(0.0, float(finish_time) - float(start_time))

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
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            continue
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
        if token == "--wall" and index + 1 < len(args):
            wall_seconds = float(args[index + 1])
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
        raise SystemExit("ingest requires MODE (unit, smoke, ui, all)")

    mode = args[0]
    wall_seconds = None
    if len(args) >= 3 and args[1] == "--wall":
        wall_seconds = float(args[2])

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

    index = 0
    while index < len(args):
        token = args[index]
        if token == "--mode" and index + 1 < len(args):
            mode_filter = args[index + 1]
            index += 2
            continue
        if token == "--last" and index + 1 < len(args):
            last_runs = int(args[index + 1])
            index += 2
            continue
        if token == "--top" and index + 1 < len(args):
            top_tests = int(args[index + 1])
            index += 2
            continue
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
    print(f"{'When':<20} {'Mode':<8} {'Wall':>8} {'Tests':>8} {'Pass':>6} {'Build':>7}  Targets")
    for entry in recent:
        when = entry.get("recorded_at", "")[:19].replace("T", " ")
        mode = entry.get("mode", "?")
        wall = format_seconds(entry.get("wall_seconds"))
        test_count = len(entry.get("tests", []))
        passed = entry.get("summary", {}).get("passed", 0)
        build = "no" if entry.get("no_build") else "yes"
        targets = ", ".join(entry.get("targets") or []) or "—"
        print(f"{when:<20} {mode:<8} {wall:>8} {test_count:>8} {passed:>6} {build:>7}  {targets}")

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
        if token == "--max-wall" and index + 1 < len(args):
            max_wall = float(args[index + 1])
            index += 2
            continue
        if token == "--skip-if-missing":
            skip_if_missing = True
            index += 1
            continue
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

    if float(duration_seconds) > max_wall:
        raise SystemExit(
            f"Timing budget exceeded for '{mode}': "
            f"{format_seconds(float(duration_seconds))} ({duration_source}) > "
            f"{format_seconds(max_wall)}"
        )

    print(
        f"Timing budget OK for '{mode}': "
        f"{format_seconds(float(duration_seconds))} ({duration_source}) <= "
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
