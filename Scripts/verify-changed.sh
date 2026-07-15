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
PATH_MODE="working-tree"
declare -a requested_paths=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --isolate)
      ISOLATE=true
      TRINKET_ISOLATE=1
      export TRINKET_ISOLATE
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/verify-changed.sh [--dry-run] [--isolate] [--paths <file> ...]

Classifies task-scoped changes when --paths is supplied, otherwise all working-tree
changes. It runs any required generation once, then the smallest focused
verification commands sequentially. It deliberately does not run pre-push or
pre-merge gates. Paths are repository-relative; --paths consumes all remaining
arguments.

--isolate acquires a reusable agent simulator slot (Trinket Agent N) with
DerivedData under .DerivedData/runs/agent-N/ so this verification does not
collide with another agent on the same Mac. Agents should always pass --isolate.
Humans and CI may omit it to keep the shared warm cache (.DerivedData + Trinket CI).
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

if [[ ${#TRINKET_CHANGED_PATHS[@]} -eq 0 ]]; then
  echo "No working-tree changes to verify."
  exit 0
fi

trinket_classify_paths
trinket_build_verification_plan
commands=()
if (( ${#TRINKET_VERIFICATION_COMMANDS[@]} > 0 )); then commands=("${TRINKET_VERIFICATION_COMMANDS[@]}"); fi
smoke_target_unresolved="$TRINKET_SMOKE_TARGET_UNRESOLVED"

if [[ ${#commands[@]} -eq 0 ]]; then
  echo "No source verification selected for the current changes."
  if [[ "$smoke_target_unresolved" == true ]]; then
    echo "UI note: no single smoke owner could be inferred; choose the closest existing Smoke* class or add focused coverage. Do not substitute bare smoke."
    echo "Run that focused smoke target directly before handoff."
  else
    echo "Review docs/tooling changes directly; use ci-gate or a task-specific command when appropriate."
  fi
  exit 0
fi

echo "Verification plan (sequential):"
printf '  %s\n' "${commands[@]}"
if [[ "$smoke_target_unresolved" == true ]]; then
  echo "UI note: no single smoke owner could be inferred for every path; choose the closest existing Smoke* class or add focused coverage. Do not substitute bare smoke."
fi
if [[ "$DRY_RUN" == true ]]; then
  if [[ "$ISOLATE" == true ]]; then
    TRINKET_SIM_SLOT_SKIP_ACQUIRE=1 trinket_run_env_init
    trinket_run_env_print
  fi
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
  echo ""
  echo "=== $command ==="
  eval "$command"
done
