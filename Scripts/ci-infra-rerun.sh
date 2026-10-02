#!/usr/bin/env bash
# Detect simulator/XCUITest launch infrastructure failures on a GitHub Actions
# run and optionally rerun only the failed jobs once.
#
# Used by ./Scripts/agent-watch-ci.sh.
# Real product/test failures must not match.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/infrastructure-patterns.sh
source ./Scripts/lib/infrastructure-patterns.sh

RUN_ID=""
DO_RERUN=false

usage() {
  cat <<'EOF'
Usage: ./Scripts/ci-infra-rerun.sh --run-id <id> [--rerun]

Exits 0 when every failed job has simulator/XCUITest launch infrastructure evidence.
With --rerun, also runs `gh run rerun <id> --failed` once.

Without --rerun, exit 1 means "not infra" (or could not classify).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --rerun)
      DO_RERUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$RUN_ID" ]]; then
  echo "Missing --run-id" >&2
  usage >&2
  exit 2
fi

failure_looks_like_simulator_infrastructure() {
  local run_id="$1"
  local failed_jobs job_id evidence pattern
  # --failed reruns every failed job. One launch flake must not cause a
  # concurrent product or gate failure to be classified as infrastructure.
  failed_jobs="$(gh run view "$run_id" --json jobs --jq '
    [.jobs[]? | select(.conclusion == "failure")] as $failed
    | if ($failed | length) > 0 and all($failed[];
        .name | test("UI|Smoke|ui|smoke|Unit|unit|Exhaustive"))
      then $failed[].databaseId else empty end
  ' 2>/dev/null)" || return 1
  [[ -n "$failed_jobs" ]] || return 1
  pattern="$(trinket_infrastructure_failure_pattern)"
  while IFS= read -r job_id; do
    [[ "$job_id" =~ ^[0-9]+$ ]] || return 1
    evidence="$(gh run view "$run_id" --job "$job_id" --log-failed 2>/dev/null)" || return 1
    # A pipe into grep -q can make printf exit on SIGPIPE for large logs;
    # pipefail would then hide the match, including a real product failure.
    if grep -iqE "$(trinket_product_test_failure_pattern)" <<< "$evidence"; then
      return 1
    fi
    grep -iqE "$pattern" <<< "$evidence" || return 1
  done <<< "$failed_jobs"
}

if ! failure_looks_like_simulator_infrastructure "$RUN_ID"; then
  echo "Run $RUN_ID failures do not look like simulator/XCUITest infrastructure."
  exit 1
fi

echo "Run $RUN_ID failures look like simulator/XCUITest infrastructure."
if [[ "$DO_RERUN" == true ]]; then
  echo "Rerunning failed jobs once..."
  gh run rerun "$RUN_ID" --failed
fi
exit 0
