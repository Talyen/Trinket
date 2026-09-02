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
KEEP=false
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset) MODE="reset" ;;
    --stage-artifacts) MODE="stage" ;;
    --cleanup) MODE="cleanup" ;;
    --keep) KEEP=true ;;
    -*)
      echo "Unknown option: $1" >&2
      echo "Usage: ./Scripts/ci-diagnostics.sh [--reset | --stage-artifacts <RESULTS_DIR> <ARTIFACT_DIR> | --cleanup [--keep]] [RESULTS_DIR]" >&2
      exit 2
      ;;
    *) POSITIONAL+=("$1") ;;
  esac
  shift
done

case "$MODE" in
  stage)
    if [[ ${#POSITIONAL[@]} -ne 2 ]]; then
      echo "Usage: ./Scripts/ci-diagnostics.sh --stage-artifacts <RESULTS_DIR> <ARTIFACT_DIR>" >&2
      exit 2
    fi
    ;;
  *)
    if [[ ${#POSITIONAL[@]} -gt 1 ]]; then
      echo "Usage: ./Scripts/ci-diagnostics.sh [--reset | --cleanup [--keep]] [RESULTS_DIR]" >&2
      exit 2
    fi
    ;;
esac
export RESULTS_DIR="${POSITIONAL[0]:-$PWD/.DerivedData/TestResults}"
OUTPUT_PATH="$RESULTS_DIR/ci-diagnostics.json"

mkdir -p "$RESULTS_DIR"

if [[ "$MODE" == "reset" ]]; then
  python3 Scripts/diagnostic_maintenance.py reset "$RESULTS_DIR"
  exit 0
fi

if [[ "$MODE" == "stage" ]]; then
  ARTIFACT_DIR="${POSITIONAL[1]:-}"
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
    python3 ./Scripts/test-timing.py report --last 8 --top 10 || true
    echo '```'
    echo
    echo "</details>"
  } >> "$GITHUB_STEP_SUMMARY"
fi
