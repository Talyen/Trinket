#!/usr/bin/env bash
# Detect simulator/XCUITest launch infrastructure failures on a GitHub Actions
# run and optionally rerun only the failed jobs once.
#
# Used by ./Scripts/agent-watch-ci.sh and the Nightly infra-rerun workflow.
# Real product/test failures must not match.
set -euo pipefail

cd "$(dirname "$0")/.."

RUN_ID=""
DO_RERUN=false
FAILURE_LOG_LINES="${TRINKET_CI_WATCH_FAILURE_LINES:-80}"

usage() {
  cat <<'EOF'
Usage: ./Scripts/ci-infra-rerun.sh --run-id <id> [--rerun]

Exits 0 when the failed jobs look like simulator/XCUITest launch infrastructure.
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

repo_slug() {
  gh repo view --json nameWithOwner -q .nameWithOwner
}

# UI / simulator suites only — never auto-rerun unit, style, or generate gates.
failure_jobs_are_ui_or_simulator() {
  local run_id="$1"
  local non_ui_failures
  non_ui_failures="$(
    gh run view "$run_id" --json jobs --jq '
      [.jobs[]?
        | select(.conclusion == "failure")
        | select(.name | test("UI|Smoke|ui|smoke|Integration|performance|Performance|App performance") | not)
      ] | length
    ' 2>/dev/null || echo 1
  )"
  [[ -n "$non_ui_failures" && "$non_ui_failures" == "0" ]]
}

failure_evidence_looks_like_infrastructure() {
  local run_id="$1"
  local repo evidence
  repo="$(repo_slug)"
  evidence="$(
    {
      gh api "repos/${repo}/actions/runs/${run_id}/jobs" --paginate \
        --jq '.jobs[] | select(.conclusion == "failure") | .id' 2>/dev/null \
        | while read -r job_id; do
            [[ -z "$job_id" ]] && continue
            gh api "repos/${repo}/check-runs/${job_id}/annotations" --jq '
              .[]? | .message // empty
            ' 2>/dev/null || true
          done
      gh run view "$run_id" --log-failed 2>/dev/null | tail -n "$FAILURE_LOG_LINES" || true
    } | tr '\n' ' '
  )"

  [[ "$evidence" =~ [Tt]imed\ out\ while\ launching \
    || "$evidence" =~ [Ff]ailed\ to\ launch \
    || "$evidence" =~ [Bb]ackground\ assertion \
    || "$evidence" =~ [Cc]oreSimulator \
    || "$evidence" =~ [Uu]nable\ to\ boot \
    || "$evidence" =~ [Cc]old\ boot\ failed \
    || "$evidence" =~ [Dd]estination\ or\ simulator\ service\ failed \
    || "$evidence" =~ simulator-infrastructure ]]
}

failure_looks_like_simulator_infrastructure() {
  local run_id="$1"
  failure_jobs_are_ui_or_simulator "$run_id" \
    && failure_evidence_looks_like_infrastructure "$run_id"
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
