#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

LOCK_DIR=".DerivedData/.performance.lock"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT_DIR="${TRINKET_PERFORMANCE_OUTPUT_DIR:-.DerivedData/PerformanceResults/$TIMESTAMP}"
REPETITIONS="${TRINKET_PERFORMANCE_REPETITIONS:-5}"

mkdir -p .DerivedData "$(dirname "$OUTPUT_DIR")"
if [[ -f "$LOCK_DIR/pid" ]]; then
  read -r existing_pid < "$LOCK_DIR/pid" || existing_pid=""
  if [[ "$existing_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$existing_pid" 2>/dev/null; then
    rm -rf "$LOCK_DIR"
  fi
fi
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Battle performance lane is already in use. This runner is intentionally exclusive." >&2
  exit 1
fi
printf '%s\n' "$$" > "$LOCK_DIR/pid"
cleanup() {
  rm -rf "$LOCK_DIR"
}
trap cleanup EXIT INT TERM

mkdir -p "$OUTPUT_DIR/TestResults"
python3 - "$OUTPUT_DIR/environment.json" "$REPETITIONS" <<'PY'
import json
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

output = Path(sys.argv[1])
repetitions = int(sys.argv[2])

def command(*args: str) -> str:
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"

payload = {
    "capturedAt": datetime.now(timezone.utc).isoformat(),
    "host": platform.platform(),
    "xcode": command("xcodebuild", "-version"),
    "gitCommit": command("git", "rev-parse", "HEAD"),
    "gitDirty": bool(command("git", "status", "--porcelain")),
    "repetitionsPerScenario": repetitions,
}
output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
PY

echo "Running exclusive full-fidelity app performance matrix ($REPETITIONS repetitions/scenario)..."
TRINKET_ISOLATE=1 \
TRINKET_MAX_CONCURRENT_UI=1 \
TRINKET_PERFORMANCE_REPETITIONS="$REPETITIONS" \
RESULTS_DIR="$OUTPUT_DIR/TestResults" \
./Scripts/test.sh performance

python3 Scripts/collect-performance-results.py \
  "$OUTPUT_DIR/TestResults" \
  "$OUTPUT_DIR/reports.json"
python3 Scripts/compare-performance.py \
  --baseline Performance/Baselines/simulator-60.json \
  --results "$OUTPUT_DIR/reports.json" \
  --summary "$OUTPUT_DIR/summary.md"

echo "App performance artifacts: $OUTPUT_DIR"
