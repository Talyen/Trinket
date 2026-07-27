#!/usr/bin/env bash
# Watch GitHub Actions for the current commit; dispatch a full CI run when path
# filters skipped the real suite. Agents must run this after pushing to main.
#
# Quiet by default: poll status JSON only (no streamed watch logs). On failure,
# print failed job names, check-run annotations, and a short --log-failed excerpt
# — not the full run log.
set -euo pipefail

cd "$(dirname "$0")/.."

REF=""
SHA=""
DISPATCH_IF_FILTERED=true
INFRA_RERUN=true
WORKFLOW_NAME="Trinket CI"
SCOPE="standard"
POLL_SECONDS="${TRINKET_CI_WATCH_POLL_SECONDS:-30}"
VERBOSE=false
FAILURE_LOG_LINES="${TRINKET_CI_WATCH_FAILURE_LINES:-80}"

usage() {
  cat <<'EOF'
Usage: ./Scripts/agent-watch-ci.sh [options]

Polls the GitHub Actions run for the current (or given) commit until it
finishes. Prints compact status only (no live log stream). On failure, prints
failed job names, check-run annotations (SwiftLint / compiler), and a short log
excerpt. If the run only executed the path-
filter job, optionally dispatches a full workflow_dispatch run and watches that.
Simulator/XCUITest launch flakes get one automatic `gh run rerun --failed`.

Options:
  --ref <branch>           Branch to watch (default: current branch)
  --sha <commit>           Commit SHA (default: HEAD)
  --no-dispatch-if-filtered  Do not auto-dispatch when jobs were path-filtered
  --no-infra-rerun         Do not auto-rerun failed jobs on simulator infra flakes
  --scope <standard|exhaustive>  workflow_dispatch scope (default: standard)
  --poll-seconds <n>       Status poll interval (default: 30, or TRINKET_CI_WATCH_POLL_SECONDS)
  --verbose                Stream `gh run watch` (noisy; humans only — avoid for agents)
  -h, --help

Requires: gh authenticated for this repo.

Agent tip: run this in the background or await its exit; do not scrape live logs.
On failure, use the printed excerpt (or `gh run view <id> --log-failed`) — not the
full run log.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      REF="${2:-}"
      shift 2
      ;;
    --sha)
      SHA="${2:-}"
      shift 2
      ;;
    --no-dispatch-if-filtered)
      DISPATCH_IF_FILTERED=false
      shift
      ;;
    --no-infra-rerun)
      INFRA_RERUN=false
      shift
      ;;
    --scope)
      SCOPE="${2:-}"
      shift 2
      ;;
    --poll-seconds)
      POLL_SECONDS="${2:-}"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required for agent-watch-ci.sh" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for agent-watch-ci.sh" >&2
  exit 1
fi

if [[ -z "$REF" ]]; then
  REF="$(git rev-parse --abbrev-ref HEAD)"
fi
if [[ -z "$SHA" ]]; then
  SHA="$(git rev-parse HEAD)"
fi
if [[ ! "$SHA" =~ ^[0-9a-fA-F]{7,64}$ ]]; then
  echo "--sha must be a hexadecimal commit prefix or SHA" >&2
  exit 1
fi
requested_sha="$SHA"
if ! resolved_sha="$(git rev-parse --verify "${requested_sha}^{commit}" 2>/dev/null)"; then
  echo "--sha does not resolve to a commit: $requested_sha" >&2
  exit 1
fi
SHA="$resolved_sha"
if [[ "$SCOPE" != standard && "$SCOPE" != exhaustive ]]; then
  echo "--scope must be standard or exhaustive" >&2
  exit 1
fi
if [[ ! "$POLL_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "--poll-seconds must be a positive integer" >&2
  exit 1
fi
if [[ ! "$FAILURE_LOG_LINES" =~ ^[1-9][0-9]*$ ]]; then
  echo "TRINKET_CI_WATCH_FAILURE_LINES must be a positive integer" >&2
  exit 1
fi

repo_slug() {
  gh repo view --json nameWithOwner -q .nameWithOwner
}

wait_for_run_id() {
  local sha="$1"
  local attempts=0
  local run_id=""
  while (( attempts < 36 )); do
    run_id="$(
      gh run list --workflow "$WORKFLOW_NAME" --commit "$sha" --limit 5 --json databaseId,status,event,createdAt,headSha \
        --jq 'sort_by(.createdAt) | reverse | .[0].databaseId // empty'
    )"
    if [[ -n "$run_id" ]]; then
      printf '%s\n' "$run_id"
      return 0
    fi
    attempts=$((attempts + 1))
    sleep "$POLL_SECONDS"
  done
  return 1
}

run_is_path_filtered_only() {
  local run_id="$1"
  local run_data
  run_data="$(gh run view "$run_id" --json jobs 2>/dev/null || echo '{}')"
  local non_skipped
  non_skipped="$(
    jq -r '
      [.jobs[]?
        | select(.name != "changes / Path filter" and .name != "changes")
        | select(.conclusion != "skipped" and .conclusion != "cancelled")
      ] | length' <<<"$run_data"
  )"
  local total
  total="$(
    jq -r '
      [.jobs[]?
        | select(.name != "changes / Path filter" and .name != "changes")
      ] | length' <<<"$run_data"
  )"
  if [[ -z "$non_skipped" || -z "$total" ]]; then
    return 1
  fi
  if (( total == 0 )); then
    return 0
  fi
  if (( non_skipped == 0 )); then
    return 0
  fi
  return 1
}

failure_looks_like_simulator_infrastructure() {
  local run_id="$1"
  # Shared classifier also covers Nightly Integration / App performance jobs.
  ./Scripts/ci-infra-rerun.sh --run-id "$run_id" >/dev/null
}

print_failure_triage() {
  local run_id="$1"
  local repo
  repo="$(repo_slug)"
  echo "Failed jobs:" >&2
  gh run view "$run_id" --json jobs --jq '
    .jobs[]
    | select(.conclusion == "failure")
    | "  - \(.name)"
  ' >&2 || true
  echo "" >&2
  echo "Check annotations (failed jobs):" >&2
  # SwiftLint github-actions-logging and xcodebuild diagnostics often land here
  # rather than in the last N log lines. Actions job id == check-run id.
  local job_id annotation_lines=0
  while read -r job_id; do
    [[ -z "$job_id" ]] && continue
    while read -r line; do
      [[ -z "$line" ]] && continue
      echo "  $line" >&2
      annotation_lines=$((annotation_lines + 1))
      if (( annotation_lines >= FAILURE_LOG_LINES )); then
        break 2
      fi
    done < <(
      gh api "repos/${repo}/check-runs/${job_id}/annotations" --jq '
        .[]? | "\(.path // "?"):\(.start_line // 0): \(.annotation_level): \(.message)"
      ' 2>/dev/null || true
    )
  done < <(
    gh api "repos/${repo}/actions/runs/${run_id}/jobs" --paginate \
      --jq '.jobs[] | select(.conclusion == "failure") | .id' 2>/dev/null || true
  )
  if (( annotation_lines == 0 )); then
    echo "  (none or could not fetch check-run annotations)" >&2
  fi
  echo "" >&2
  echo "Log excerpt (last ${FAILURE_LOG_LINES} lines of failed steps):" >&2
  # Full --log-failed can be huge; keep a short tail for agent context.
  if ! gh run view "$run_id" --log-failed 2>/dev/null | tail -n "$FAILURE_LOG_LINES" >&2; then
    echo "(could not fetch --log-failed; try: gh run view $run_id --log-failed)" >&2
  fi
  echo "" >&2
  echo "Triage: Docs/AgentContext/ci-diagnostics.md | gh run view $run_id --log-failed" >&2
}

watch_run_quiet() {
  local run_id="$1"
  local url status conclusion summary last_summary=""
  url="https://github.com/$(repo_slug)/actions/runs/$run_id"
  echo "Polling CI run $run_id ($url) every ${POLL_SECONDS}s (quiet)"

  while true; do
    local run_data
    run_data="$(gh run view "$run_id" --json status,conclusion,jobs 2>/dev/null || echo '{}')"
    status="$(jq -r '.status // "?"' <<<"$run_data")"
    conclusion="$(jq -r '.conclusion // empty' <<<"$run_data")"
    summary="$(
      jq -r '
        (.status // "?") as $s
        | (.conclusion // "-") as $c
        | ([.jobs[]? | select(.status == "in_progress") | .name] | join(", ")) as $active
        | ([.jobs[]? | select(.conclusion == "success") ] | length) as $ok
        | ([.jobs[]? | select(.conclusion == "failure") ] | length) as $fail
        | ([.jobs[]? | select(.conclusion == "skipped") ] | length) as $skip
        | "status=\($s) conclusion=\($c) ok=\($ok) fail=\($fail) skip=\($skip)"
          + (if $active == "" then "" else " active=\($active)" end)
      ' <<<"$run_data"
    )"
    if [[ "$summary" != "$last_summary" ]]; then
      echo "  $summary"
      last_summary="$summary"
    fi

    if [[ "$status" == "completed" ]]; then
      if [[ "$conclusion" == "success" ]]; then
        echo "CI run $run_id succeeded."
        return 0
      fi
      echo "CI run $run_id failed (conclusion=$conclusion)." >&2
      print_failure_triage "$run_id"
      return 1
    fi
    sleep "$POLL_SECONDS"
  done
}

watch_run_verbose() {
  local run_id="$1"
  echo "Streaming CI run $run_id (verbose)"
  if gh run watch "$run_id" --exit-status; then
    echo "CI run $run_id succeeded."
    return 0
  fi
  echo "CI run $run_id failed." >&2
  print_failure_triage "$run_id"
  return 1
}

watch_run() {
  if [[ "$VERBOSE" == true ]]; then
    watch_run_verbose "$1"
  else
    watch_run_quiet "$1"
  fi
}

echo "=== Agent CI watch: ref=$REF sha=${SHA:0:12} ==="

echo "Waiting for Actions run for $SHA ..."
if ! RUN_ID="$(wait_for_run_id "$SHA")"; then
  echo "No Actions run found for commit $SHA within timeout." >&2
  echo "Triggering workflow_dispatch on $REF ..."
  gh workflow run "$WORKFLOW_NAME" --ref "$REF" -f "scope=$SCOPE"
  sleep "$POLL_SECONDS"
  if ! RUN_ID="$(wait_for_run_id "$SHA")"; then
    RUN_ID=""
  fi
  if [[ -z "${RUN_ID:-}" ]]; then
    echo "Could not locate a CI run for $SHA after dispatch." >&2
    exit 1
  fi
fi

if ! watch_run "$RUN_ID"; then
  if [[ "$INFRA_RERUN" == true ]] && failure_looks_like_simulator_infrastructure "$RUN_ID"; then
    echo "Failed jobs look like simulator/XCUITest launch infrastructure; rerunning failed jobs once..."
    gh run rerun "$RUN_ID" --failed
    sleep "$POLL_SECONDS"
    if ! watch_run "$RUN_ID"; then
      exit 1
    fi
  else
    exit 1
  fi
fi

if [[ "$DISPATCH_IF_FILTERED" == true ]] && run_is_path_filtered_only "$RUN_ID"; then
  echo "CI run $RUN_ID was path-filtered (substantive jobs skipped)."
  echo "Dispatching full $WORKFLOW_NAME (scope=$SCOPE) on $REF ..."
  BEFORE="$(
    gh run list --branch "$REF" --workflow "$WORKFLOW_NAME" --limit 1 --json databaseId,createdAt \
      --jq '.[0].databaseId // empty'
  )"
  gh workflow run "$WORKFLOW_NAME" --ref "$REF" -f "scope=$SCOPE"
  DISPATCH_ID=""
  attempts=0
  while (( attempts < 36 )); do
    sleep "$POLL_SECONDS"
    CANDIDATE="$(
      gh run list --branch "$REF" --workflow "$WORKFLOW_NAME" --event workflow_dispatch --limit 10 \
        --json databaseId,status,createdAt,headSha \
        --jq 'sort_by(.createdAt) | reverse | map(select(.headSha == '"'"$SHA"'")) | .[0].databaseId // empty'
    )"
    if [[ -n "$CANDIDATE" && "$CANDIDATE" != "$BEFORE" && "$CANDIDATE" != "$RUN_ID" ]]; then
      DISPATCH_ID="$CANDIDATE"
      break
    fi
    attempts=$((attempts + 1))
  done
  if [[ -z "$DISPATCH_ID" ]]; then
    echo "Could not find workflow_dispatch run after trigger." >&2
    exit 1
  fi
  if ! watch_run "$DISPATCH_ID"; then
    if [[ "$INFRA_RERUN" == true ]] && failure_looks_like_simulator_infrastructure "$DISPATCH_ID"; then
      echo "Failed jobs look like simulator/XCUITest launch infrastructure; rerunning failed jobs once..."
      gh run rerun "$DISPATCH_ID" --failed
      sleep "$POLL_SECONDS"
      if ! watch_run "$DISPATCH_ID"; then
        exit 1
      fi
    else
      exit 1
    fi
  fi
fi

echo "=== Agent CI watch: green ==="
