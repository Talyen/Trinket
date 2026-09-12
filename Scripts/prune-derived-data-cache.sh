#!/usr/bin/env bash
# Keep incremental build state; remove indexes and old diagnostics before cache save.
# Local cleanup also reaps dead leases without mutating simulator devices.
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=run-env.sh
source ./Scripts/run-env.sh

CI_MODE=false
if [[ "${CI:-}" == "true" ]]; then
  CI_MODE=true
fi

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ci)
      CI_MODE=true
      shift
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/prune-derived-data-cache.sh [--ci] [DERIVED_DATA_PATH]

Without --ci (and when CI is unset): age-prune one-off isolated runs, bulky
TestResults/PerformanceResults/Logs, and reap dead UI/sim slots. Does not
delete Build/Intermediates or compilation caches.

With --ci or CI=true: also remove indexes, logs, and result bundles before
saving the cache. Products, intermediates, and compilation caches remain warm.
USAGE
      exit 0
      ;;
    -*)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--ci] [DERIVED_DATA_PATH]" >&2
      exit 1
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

DERIVED_DATA_PATH="${ARGS[0]:-$PWD/.DerivedData}"
RUN_MAX_AGE_DAYS="${TRINKET_RUN_MAX_AGE_DAYS:-3}"
SHARED_ROOT="$PWD/.DerivedData"
TRINKET_SHARED_DERIVED_DATA="$SHARED_ROOT"
export TRINKET_SHARED_DERIVED_DATA

if [[ ! -d "$DERIVED_DATA_PATH" ]]; then
  echo "No DerivedData at $DERIVED_DATA_PATH; nothing to prune."
  exit 0
fi

# This script removes cache contents. Resolve and constrain the target before
# any destructive operation so a mistyped argument cannot point at the repo,
# home directory, or an unrelated DerivedData tree.
DERIVED_DATA_PATH="$(cd "$DERIVED_DATA_PATH" && pwd -P)"
SHARED_ROOT="$(cd "$SHARED_ROOT" && pwd -P)"
case "$DERIVED_DATA_PATH" in
  "$SHARED_ROOT"|"$SHARED_ROOT"/*) ;;
  *)
    echo "Refusing to prune outside $SHARED_ROOT: $DERIVED_DATA_PATH" >&2
    exit 2
    ;;
esac

prune_derived_data_bulk() {
  local target="$1"
  echo "=== Pruning DerivedData cache bulk under $target ==="

  # Test jobs receive their own products-only archive. Keep build state here.
  trinket_prune_rebuildable_derived_data "$target"

  # Per-package DerivedData tenants (parallel package builds).
  if [[ -d "$target/packages" ]]; then
    find "$target/packages" -mindepth 1 -maxdepth 1 -type d -print0 \
      | while IFS= read -r -d '' package_dd; do
        trinket_prune_rebuildable_derived_data "$package_dd"
      done
  fi

  # Drop xcresults from the cache blob (uploaded separately as artifacts).
  find "$target/TestResults" -type d -name '*.xcresult' -prune -exec rm -rf {} + 2>/dev/null || true
}

if [[ "$CI_MODE" == "true" ]]; then
  prune_derived_data_bulk "$DERIVED_DATA_PATH"
else
  echo "=== Skipping CI index/log cleanup (pass --ci or set CI=true) ==="
fi

echo "=== Age-pruning bulky DerivedData artifacts (max age ${RUN_MAX_AGE_DAYS}d) ==="
trinket_derived_data_age_prune

# Dead UI / sim concurrency slots (pid no longer alive).
if [[ -d "$SHARED_ROOT/.active-ui" ]]; then
  echo "=== Reaping dead UI concurrency slots ==="
  TRINKET_UI_ACTIVE_DIR="$SHARED_ROOT/.active-ui"
  trinket_ui_slot_reap
fi
if [[ -d "$SHARED_ROOT/.active-sim" ]]; then
  echo "=== Reaping dead agent simulator slots ==="
  TRINKET_SIM_ACTIVE_DIR="$SHARED_ROOT/.active-sim"
  trinket_sim_slot_reap
fi

# Simulator lifecycle belongs to run-env self-clean start + EXIT (Preview;
# single-warm Booted cap). This script never mutates devices.

echo "=== DerivedData prune complete ==="
