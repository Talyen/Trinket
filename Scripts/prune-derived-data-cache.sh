#!/usr/bin/env bash
# Strip bulky DerivedData intermediates before CI cache save.
# Keeps Build/ products and module caches needed for test-without-building.
# Also reaps stale isolated run dirs and dead UI/sim concurrency slots.
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="${1:-$PWD/.DerivedData}"
RUN_MAX_AGE_DAYS="${TRINKET_RUN_MAX_AGE_DAYS:-3}"
SHARED_ROOT="$PWD/.DerivedData"

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

echo "=== Pruning DerivedData cache bulk under $DERIVED_DATA_PATH ==="

# Index / symbol stores are rebuildable and dominate cache size.
# Keep Build/Products, ModuleCache, and SourcePackages so --no-build stays warm.
# Intermediates are only needed for incremental compilation and add substantial
# transfer cost to every fan-out test job.
rm -rf \
  "$DERIVED_DATA_PATH/Build/Intermediates.noindex" \
  "$DERIVED_DATA_PATH/Build/ProfileData" \
  "$DERIVED_DATA_PATH/Index.noindex" \
  "$DERIVED_DATA_PATH/Index" \
  "$DERIVED_DATA_PATH/SymbolCache" \
  "$DERIVED_DATA_PATH/SDKStatCaches.noindex" \
  "$DERIVED_DATA_PATH/CompilationCache.noindex" \
  "$DERIVED_DATA_PATH/Logs" \
  2>/dev/null || true

# Per-package DerivedData tenants (parallel package builds).
if [[ -d "$DERIVED_DATA_PATH/packages" ]]; then
  find "$DERIVED_DATA_PATH/packages" -mindepth 1 -maxdepth 1 -type d -print0 \
    | while IFS= read -r -d '' package_dd; do
      rm -rf \
        "$package_dd/Build/Intermediates.noindex" \
        "$package_dd/Build/ProfileData" \
        "$package_dd/Index.noindex" \
        "$package_dd/Index" \
        "$package_dd/SymbolCache" \
        "$package_dd/SDKStatCaches.noindex" \
        "$package_dd/CompilationCache.noindex" \
        "$package_dd/Logs" \
        2>/dev/null || true
    done
fi

# Drop xcresults from the cache blob (uploaded separately as artifacts).
find "$DERIVED_DATA_PATH/TestResults" -type d -name '*.xcresult' -prune -exec rm -rf {} + 2>/dev/null || true

# Isolated agent tenants under .DerivedData/runs/<id>.
# Keep warm reusable slots (.DerivedData/runs/agent-N); age-prune one-off run ids only.
if [[ -d "$SHARED_ROOT/runs" ]]; then
  echo "=== Pruning one-off isolated runs older than ${RUN_MAX_AGE_DAYS}d under $SHARED_ROOT/runs ==="
  find "$SHARED_ROOT/runs" -mindepth 1 -maxdepth 1 -type d \
    ! -name 'agent-*' \
    -mtime "+${RUN_MAX_AGE_DAYS}" \
    -exec rm -rf {} + 2>/dev/null || true
fi

# Dead UI / sim concurrency slots (pid no longer alive).
# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
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

# Simulator lifecycle belongs to ensure-simulator.sh, which validates device
# names and ownership before reset/delete. Cache pruning never mutates devices.

echo "=== DerivedData prune complete ==="
