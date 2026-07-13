#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Keep source routing aligned with changed-source-summary.sh and
# agent-context.sh.
# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh

DRY_RUN=false
PATH_MODE="working-tree"
declare -a requested_paths=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/verify-changed.sh [--dry-run] [--paths <file> ...]

Classifies task-scoped changes when --paths is supplied, otherwise all working-tree
changes. It runs any required generation once, then the smallest focused
verification commands sequentially. It deliberately does not run pre-push or
pre-merge gates. Paths are repository-relative; --paths consumes all remaining
arguments.
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
needs_smoke="$TRINKET_NEEDS_SMOKE"

if [[ ${#commands[@]} -eq 0 ]]; then
  echo "No source verification selected for the current changes."
  echo "Review docs/tooling changes directly; use ci-gate or a task-specific command when appropriate."
  exit 0
fi

echo "Verification plan (sequential):"
printf '  %s\n' "${commands[@]}"
if [[ "$needs_smoke" == true ]]; then
  echo "UI note: bare smoke is only the Homestead canary; run ./Scripts/test.sh smoke <Class> for the affected flow."
fi
if [[ "$DRY_RUN" == true ]]; then
  exit 0
fi

for command in "${commands[@]}"; do
  echo ""
  echo "=== $command ==="
  eval "$command"
done
