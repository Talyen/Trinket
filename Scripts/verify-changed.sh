#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Keep source routing aligned with changed-source-summary.sh and
# agent-context.sh.
# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh
# shellcheck source=Scripts/run-env.sh
source Scripts/run-env.sh

DRY_RUN=false
ISOLATE=false
PUSH_READY=false
QUIET=false
PATH_MODE="working-tree"
declare -a requested_paths=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --quiet) QUIET=true ;;
    --isolate)
      ISOLATE=true
      TRINKET_ISOLATE=1
      export TRINKET_ISOLATE
      ;;
    --push-ready)
      # Commit completeness: force XcodeGen + assert vs HEAD (not --idempotent).
      PUSH_READY=true
      TRINKET_PUSH_READY=true
      export TRINKET_PUSH_READY
      TRINKET_REQUIRE_PINNED_TOOLS=1
      export TRINKET_REQUIRE_PINNED_TOOLS
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/verify-changed.sh [--dry-run] [--quiet] [--isolate] [--push-ready] [--paths <file> ...]

Classifies task-scoped changes when --paths is supplied, otherwise all working-tree
changes. It runs any required generation once, then the smallest focused
verification commands sequentially. It deliberately does not run pre-push or
pre-merge gates. Paths are repository-relative; --paths consumes all remaining
arguments.

--isolate acquires a reusable agent simulator slot (Trinket Agent N) with
DerivedData under .DerivedData/runs/agent-N/ so this verification does not
collide with another agent on the same Mac. Agents should always pass --isolate.
Humans and CI may omit it to keep the shared warm cache (.DerivedData + Trinket CI).

--push-ready switches generation asserts from --idempotent (task-scoped) to
commit-completeness (force XcodeGen + assert vs HEAD, conditional --assets).
Prefer ./Scripts/agent-push-gate.sh for a dedicated push gate (generate/assert only);
use this flag when you also want the path-scoped style/package/smoke/compile plan
in the same run.

--quiet prints the selected checks, one PASS/FAIL line per check, the advisory
change budget, and at most TRINKET_VERIFY_FAILURE_LINES (default 80) lines from a
failed check. Full command output remains the default.
USAGE
      exit 0
      ;;
    --paths)
      PATH_MODE="explicit"
      shift
      if [[ $# -eq 0 ]]; then
        echo "--paths requires at least one repository-relative path" >&2
        exit 1
      fi
      requested_paths=("$@")
      break
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

trinket_collect_paths "$PATH_MODE" "${requested_paths[@]-}"

run_change_budget() {
  if [[ "$PATH_MODE" == "explicit" ]]; then
    ./Scripts/change-budget.sh --paths "${TRINKET_CHANGED_PATHS[@]}"
  else
    ./Scripts/change-budget.sh
  fi
}

if [[ ${#TRINKET_CHANGED_PATHS[@]} -eq 0 ]]; then
  if [[ "$PUSH_READY" == true ]]; then
    echo "No working-tree changes; running agent-push-gate for commit completeness."
    if [[ "$DRY_RUN" == true ]]; then
      echo "Would run: ./Scripts/agent-push-gate.sh"
      exit 0
    fi
    exec ./Scripts/agent-push-gate.sh
  fi
  echo "No working-tree changes to verify."
  exit 0
fi

if [[ "$PUSH_READY" == true ]]; then
  echo "=== Push-ready: ensuring pinned tools ==="
  if [[ "$DRY_RUN" == false ]]; then
    ./Scripts/ensure-ci-tools.sh
    export PATH="$PWD/.tools:$PATH"
  fi
fi

trinket_classify_paths
trinket_build_verification_plan
commands=()
if (( ${#TRINKET_VERIFICATION_COMMANDS[@]} > 0 )); then commands=("${TRINKET_VERIFICATION_COMMANDS[@]}"); fi
smoke_target_unresolved="$TRINKET_SMOKE_TARGET_UNRESOLVED"
app_compile_skipped_no_xcode="$TRINKET_APP_COMPILE_SKIPPED_NO_XCODE"

if [[ ${#commands[@]} -eq 0 ]]; then
  if [[ "$PUSH_READY" == true ]]; then
    echo "No source verification selected; falling back to agent-push-gate."
    if [[ "$DRY_RUN" == true ]]; then
      echo "Would run: ./Scripts/agent-push-gate.sh"
      exit 0
    fi
    exec ./Scripts/agent-push-gate.sh
  fi
  echo "No source verification selected for the current changes."
  if [[ "$smoke_target_unresolved" == true ]]; then
    echo "UI note: no single smoke owner was inferred. Apply the Testing rubric; add coverage only for a qualifying unique shipping outcome. Do not substitute bare smoke."
  else
    echo "Review docs/tooling changes directly; use ci-gate or a task-specific command when appropriate."
  fi
  if [[ "$app_compile_skipped_no_xcode" == true ]]; then
    echo "Compile note: app compile tier skipped (no xcodebuild). Style PASS is not compile-clean — report the skip; CI build-for-testing owns Swift 6 / macro errors."
  fi
  run_change_budget
  exit 0
fi

echo "Verification plan (${#commands[@]} sequential check(s)):"
printf '  %s\n' "${commands[@]}"
if [[ "$smoke_target_unresolved" == true ]]; then
  echo "UI note: no single smoke owner was inferred. Apply the Testing rubric; add coverage only for a qualifying unique shipping outcome. Do not substitute bare smoke."
fi
if [[ "$app_compile_skipped_no_xcode" == true ]]; then
  echo "Compile note: app compile tier skipped (no xcodebuild). Style PASS is not compile-clean — report the skip; CI build-for-testing owns Swift 6 / macro errors."
fi
if [[ "$DRY_RUN" == true ]]; then
  if [[ "$ISOLATE" == true ]]; then
    TRINKET_SIM_SLOT_SKIP_ACQUIRE=1 trinket_run_env_init
    trinket_run_env_print
  fi
  echo "Would report: ./Scripts/change-budget.sh"
  exit 0
fi

if [[ "$ISOLATE" == true ]]; then
  trinket_run_env_init
  trinket_run_env_print
  # Export tenant env so every eval'd child shares one agent slot + DerivedData.
  export TRINKET_ISOLATE TRINKET_RUN_ID DERIVED_DATA_PATH RESULTS_DIR
  export TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TMPDIR TMP TEMP
  export TRINKET_DIAGNOSTICS_SESSION_ID TRINKET_UI_ACTIVE_DIR TRINKET_SIM_ACTIVE_DIR
  export TRINKET_MAX_CONCURRENT_UI TRINKET_MAX_AGENT_SIMS
fi

for command in "${commands[@]}"; do
  if [[ "$QUIET" == true ]]; then
    quiet_log=$(mktemp -t trinket-verify.XXXXXX)
    if eval "$command" > "$quiet_log" 2>&1; then
      echo "PASS: $command"
      rm -f "$quiet_log"
    else
      status=$?
      echo "FAIL: $command"
      tail -n "${TRINKET_VERIFY_FAILURE_LINES:-80}" "$quiet_log"
      rm -f "$quiet_log"
      exit "$status"
    fi
  else
    echo ""
    echo "=== $command ==="
    eval "$command"
  fi
done

run_change_budget
