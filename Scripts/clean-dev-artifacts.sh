#!/usr/bin/env bash
# Emergency / offline reclaim wrapper around run-env self-clean helpers.
#
# Prefer normal verify/test EXIT paths — those already reclaim Preview sims,
# shut down + erase idle Trinket Agent devices when the agent pool is empty
# (Trinket CI stays warm), and age-prune bulky DerivedData. Use this script
# only when you need the same reclaim without running verify/test (for example
# after a crashed agent).
set -euo pipefail

cd "$(dirname "$0")/.."

DRY_RUN=false

usage() {
  cat <<'USAGE'
Usage: ./Scripts/clean-dev-artifacts.sh [--dry-run]

Emergency wrapper for the same reclaim that verify/test EXIT already performs
via Scripts/run-env.sh (Preview sims, idle Trinket Agent device data, DerivedData
age-prune). Never erases shared Trinket CI. Not part of the normal workflow.

Options:
  --dry-run   Print the helpers that would run
  -h, --help  Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      echo "Unexpected argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
trinket_run_env_init

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY-RUN: trinket_preview_sims_reclaim"
  echo "DRY-RUN: trinket_simulator_cleanup_idle_pool"
  echo "DRY-RUN: trinket_derived_data_age_prune"
  exit 0
fi

echo "=== Emergency clean-dev-artifacts (prefer verify/test EXIT) ==="
trinket_preview_sims_reclaim
# Force isolate so idle-pool can reclaim leftover Agents even when this shell
# was not an isolate tenant. Shared Trinket CI is still never erased.
TRINKET_ISOLATE=1 trinket_simulator_cleanup_idle_pool
trinket_derived_data_age_prune
echo "=== clean-dev-artifacts complete ==="
