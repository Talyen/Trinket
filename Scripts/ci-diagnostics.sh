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
MODE="aggregate"
if [[ "${1:-}" == "--reset" ]]; then MODE="reset"; shift; fi
if [[ "${1:-}" == "--stage-artifacts" ]]; then MODE="stage"; shift; fi
if [[ "${1:-}" == "--cleanup" ]]; then MODE="cleanup"; shift; fi
KEEP=false
if [[ "${1:-}" == "--keep" ]]; then KEEP=true; shift; fi
export RESULTS_DIR="${1:-$PWD/.DerivedData/TestResults}"
OUTPUT_PATH="$RESULTS_DIR/ci-diagnostics.json"

mkdir -p "$RESULTS_DIR"

if [[ "$MODE" == "reset" ]]; then
  python3 Scripts/diagnostic_maintenance.py reset "$RESULTS_DIR"
  exit 0
fi

if [[ "$MODE" == "stage" ]]; then
  ARTIFACT_DIR="${2:-}"
  if [[ -z "$ARTIFACT_DIR" || "$ARTIFACT_DIR" == "$RESULTS_DIR" || "$ARTIFACT_DIR" == "/" ]]; then
    echo "Usage: ./Scripts/ci-diagnostics.sh --stage-artifacts <RESULTS_DIR> <ARTIFACT_DIR>" >&2
    exit 2
  fi
  python3 Scripts/diagnostic_maintenance.py stage "$RESULTS_DIR" "$ARTIFACT_DIR"
  exit 0
fi

if [[ "$MODE" == "cleanup" ]]; then
  if [[ "$KEEP" == true ]]; then
    python3 Scripts/diagnostic_maintenance.py cleanup "$RESULTS_DIR" --keep
  else
    python3 Scripts/diagnostic_maintenance.py cleanup "$RESULTS_DIR"
  fi
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
