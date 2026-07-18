#!/usr/bin/env bash
# Watch GitHub Actions for the current commit; dispatch a full CI run when path
# filters skipped the real suite. Agents must run this after pushing to main.
set -euo pipefail

cd "$(dirname "$0")/.."

REF=""
SHA=""
DISPATCH_IF_FILTERED=true
WORKFLOW_NAME="Trinket CI"
SCOPE="standard"
POLL_SECONDS=5

usage() {
  cat <<'EOF'
Usage: ./Scripts/agent-watch-ci.sh [options]

Watches the GitHub Actions run for the current (or given) commit until it
finishes. If the run only executed the path-filter job (all test/codegen jobs
skipped), optionally dispatches a full workflow_dispatch run and watches that.

Options:
  --ref <branch>           Branch to watch (default: current branch)
  --sha <commit>           Commit SHA (default: HEAD)
  --no-dispatch-if-filtered  Do not auto-dispatch when jobs were path-filtered
  --scope <standard|exhaustive>  workflow_dispatch scope (default: standard)
  -h, --help

Requires: gh authenticated for this repo.
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
    --scope)
      SCOPE="${2:-}"
      shift 2
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

if [[ -z "$REF" ]]; then
  REF="$(git rev-parse --abbrev-ref HEAD)"
fi
if [[ -z "$SHA" ]]; then
  SHA="$(git rev-parse HEAD)"
fi

wait_for_run_id() {
  local sha="$1"
  local attempts=0
  local run_id=""
  while (( attempts < 36 )); do
    run_id="$(
      gh run list --commit "$sha" --limit 5 --json databaseId,status,event,createdAt \
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
  # True when every substantive job (anything except path filter) was skipped/cancelled,
  # or no substantive jobs exist.
  local non_skipped
  non_skipped="$(
    gh run view "$run_id" --json jobs --jq '
      [.jobs[]
        | select(.name != "changes / Path filter" and .name != "changes")
        | select(.conclusion != "skipped" and .conclusion != "cancelled")
      ] | length'
  )"
  local total
  total="$(
    gh run view "$run_id" --json jobs --jq '
      [.jobs[]
        | select(.name != "changes / Path filter" and .name != "changes")
      ] | length'
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

watch_run() {
  local run_id="$1"
  echo "Watching CI run $run_id (https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions/runs/$run_id)"
  if gh run watch "$run_id" --exit-status; then
    echo "CI run $run_id succeeded."
    return 0
  fi
  echo "CI run $run_id failed." >&2
  echo "Failed jobs:" >&2
  gh run view "$run_id" --json jobs --jq '
    .jobs[]
    | select(.conclusion == "failure")
    | "  - \(.name)"
  ' >&2 || true
  echo "Triage: ./Scripts/ci-diagnostics.sh (or gh run view $run_id --log-failed)" >&2
  return 1
}

echo "=== Agent CI watch: ref=$REF sha=${SHA:0:12} ==="

echo "Waiting for Actions run for $SHA ..."
if ! RUN_ID="$(wait_for_run_id "$SHA")"; then
  echo "No Actions run found for commit $SHA within timeout." >&2
  echo "Triggering workflow_dispatch on $REF ..."
  gh workflow run "$WORKFLOW_NAME" --ref "$REF" -f "scope=$SCOPE"
  sleep "$POLL_SECONDS"
  if ! RUN_ID="$(wait_for_run_id "$SHA")"; then
    # workflow_dispatch may attach to the same SHA; also try latest on branch.
    RUN_ID="$(
      gh run list --branch "$REF" --workflow "$WORKFLOW_NAME" --limit 1 --json databaseId \
        --jq '.[0].databaseId // empty'
    )"
  fi
  if [[ -z "${RUN_ID:-}" ]]; then
    echo "Could not locate a CI run after dispatch." >&2
    exit 1
  fi
fi

if ! watch_run "$RUN_ID"; then
  exit 1
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
      gh run list --branch "$REF" --workflow "$WORKFLOW_NAME" --event workflow_dispatch --limit 3 \
        --json databaseId,status,createdAt \
        --jq 'sort_by(.createdAt) | reverse | .[0].databaseId // empty'
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
    exit 1
  fi
fi

echo "=== Agent CI watch: green ==="
