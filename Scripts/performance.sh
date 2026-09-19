#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

LOCK_DIR=".DerivedData/.performance.lock"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT_DIR="${TRINKET_PERFORMANCE_OUTPUT_DIR:-.DerivedData/PerformanceResults/$TIMESTAMP}"
# One measured report per scenario. Repetition overrides are optional.
REPETITIONS="${TRINKET_PERFORMANCE_REPETITIONS:-1}"
SELECTION=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario|--group)
      [[ $# -ge 2 ]] || { echo "$1 needs a value" >&2; exit 1; }
      SELECTION+=(--select "$2"); shift 2 ;;
    --list) exec python3 Scripts/performance-scenarios.py --list ;;
    --help|-h) echo "Usage: $0 [--scenario ID | --group GROUP]... [--list]"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if ! [[ "$REPETITIONS" =~ ^[1-9][0-9]*$ ]]; then
  echo "TRINKET_PERFORMANCE_REPETITIONS must be a positive integer (got: $REPETITIONS)" >&2
  exit 1
fi

mkdir -p .DerivedData "$(dirname "$OUTPUT_DIR")"
# shellcheck source=lib/lock.sh
source Scripts/lib/lock.sh
# trinket_dir_lock_acquire chains lock release onto EXIT and installs signal
# traps with child reaping; no bespoke cleanup is needed here.
if ! trinket_dir_lock_acquire "$LOCK_DIR" 0; then
  echo "Battle performance lane is already in use. This runner is intentionally exclusive." >&2
  exit 1
fi

if [[ -e "$OUTPUT_DIR" ]]; then
  echo "Performance output already exists; choose a fresh TRINKET_PERFORMANCE_OUTPUT_DIR: $OUTPUT_DIR" >&2
  exit 1
fi
mkdir -p "$OUTPUT_DIR/TestResults"
python3 Scripts/performance-scenarios.py ${SELECTION[@]+"${SELECTION[@]}"} --output "$OUTPUT_DIR/baseline.json" > "$OUTPUT_DIR/tests.txt"
TESTS=()
while IFS= read -r test; do TESTS+=("$test"); done < "$OUTPUT_DIR/tests.txt"
export TRINKET_PERFORMANCE_SCENARIOS
TRINKET_PERFORMANCE_SCENARIOS="$(python3 -c 'import json,sys; print(",".join(json.load(open(sys.argv[1]))["scenarios"]))' "$OUTPUT_DIR/baseline.json")"
export TRINKET_PERFORMANCE_TEST_SCENARIOS
TRINKET_PERFORMANCE_TEST_SCENARIOS="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))["testScenarios"]))' "$OUTPUT_DIR/baseline.json")"
# Budget the whole suite separately from the per-interaction 60-second watchdog.
wall_budget=$((300 + ${#TESTS[@]} * 60 * REPETITIONS))
if (( wall_budget < 1200 )); then wall_budget=1200; fi
export TRINKET_XCODE_WALL_TIMEOUT_SECONDS="${TRINKET_XCODE_WALL_TIMEOUT_SECONDS:-$wall_budget}"
python3 Scripts/performance_environment.py "$OUTPUT_DIR/environment.json" "$REPETITIONS"

echo "Running exclusive full-fidelity app performance matrix (${REPETITIONS} measured run(s)/scenario)..."
TRINKET_ISOLATE=1 \
TRINKET_MAX_CONCURRENT_UI=1 \
TRINKET_PERFORMANCE_REPETITIONS="$REPETITIONS" \
TRINKET_CLEANUP_TEST_ARTIFACTS=0 \
RESULTS_DIR="$OUTPUT_DIR/TestResults" \
./Scripts/test.sh performance "${TESTS[@]}" || test_status=$?

collection_status=0
python3 Scripts/collect-performance-results.py \
  "$OUTPUT_DIR/TestResults" \
  "$OUTPUT_DIR/reports.json" || collection_status=$?
if [[ "$collection_status" -ne 0 ]]; then
  echo "Performance capture incomplete; retained available evidence: $OUTPUT_DIR" >&2
fi
if [[ "$REPETITIONS" -gt 1 ]]; then
  python3 Scripts/aggregate-performance-results.py \
    --results "$OUTPUT_DIR/reports.json" \
    --output "$OUTPUT_DIR/aggregate.json" \
    --summary "$OUTPUT_DIR/aggregate.md" \
    --expected-repetitions "$REPETITIONS" \
    --baseline "$OUTPUT_DIR/baseline.json" || comparison_status=$?
  echo "Repeated app performance artifacts: $OUTPUT_DIR"
  exit $(( ${test_status:-0} != 0 || collection_status != 0 || ${comparison_status:-0} != 0 ))
fi

python3 Scripts/compare-performance.py \
  --baseline "$OUTPUT_DIR/baseline.json" \
  --results "$OUTPUT_DIR/reports.json" \
  --summary "$OUTPUT_DIR/summary.md" || comparison_status=$?

echo "App performance artifacts: $OUTPUT_DIR"

exit $(( ${test_status:-0} != 0 || collection_status != 0 || ${comparison_status:-0} != 0 ))
