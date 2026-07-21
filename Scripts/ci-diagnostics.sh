#!/usr/bin/env bash
# Aggregate structured diagnostics emitted by each CI test invocation.
#
# This script is intentionally read-only with respect to test output.  The
# invocation reporters own xcresult parsing on failures; this step only
# combines their JSON reports/manifests and writes the CI-level status.  It
# must never change the test command's exit status (the workflow records that
# status separately).
set -euo pipefail

cd "$(dirname "$0")/.."
RESET=false
if [[ "${1:-}" == "--reset" ]]; then
  RESET=true
  shift
fi
RESULTS_DIR="${1:-$PWD/.DerivedData/TestResults}"
OUTPUT_PATH="$RESULTS_DIR/ci-diagnostics.json"

mkdir -p "$RESULTS_DIR"

if [[ "$RESET" == "true" ]]; then
  # DerivedData may be restored from a previous CI job.  Remove only
  # diagnostics/status artifacts; current and cached raw logs/xcresults are
  # intentionally retained for the test command and artifact upload.
  find "$RESULTS_DIR" -maxdepth 1 -type f \
    \( -name '*-diagnostics.json' -o -name '*-diagnostics.md' \
    -o -name '*-diagnostics.annotations' -o -name '*-invocation.json' \
    -o -name 'ci-diagnostics.json' \) -delete
  find "$RESULTS_DIR" -maxdepth 1 -type d -name '*-diagnostics.attachments' -prune -exec rm -rf {} +
  echo "Cleared prior CI diagnostic/status artifacts in $RESULTS_DIR"
  exit 0
fi

python3 "$(dirname "$0")/ci-diagnostics.py" "$RESULTS_DIR" "$OUTPUT_PATH"

# Timing is already structured in timing-log.jsonl.  Keep this optional report
# for humans, without reparsing any xcresult bundle.
if [[ -n "${GITHUB_STEP_SUMMARY:-}" && -f "$RESULTS_DIR/timing-log.jsonl" ]]; then
  {
    echo
    echo "<details><summary>Timing report</summary>"
    echo
    echo '```text'
    ./Scripts/test-timing.sh report --last 8 --top 10 || true
    echo '```'
    echo
    echo "</details>"
  } >> "$GITHUB_STEP_SUMMARY"
fi
