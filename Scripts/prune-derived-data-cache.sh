#!/usr/bin/env bash
# Prune DerivedData for CI cache save, and reap stale local isolation metadata.
#
# Destructive Intermediate/Index/compilation-cache wipes run only when CI=true
# or --ci is passed (GitHub Actions cache-save path). Local default runs keep
# Build/Intermediates so incremental compiles stay warm; they still age-prune
# one-off .DerivedData/runs/<id> tenants and reap dead UI/sim slots.
#
# Never mutates simulator devices — that stays in ensure-simulator.sh.
set -euo pipefail

cd "$(dirname "$0")/.."

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

Without --ci (and when CI is unset): age-prune one-off isolated runs and reap
dead UI/sim slots. Does not delete Build/Intermediates or compilation caches.

With --ci or CI=true: also strip bulky rebuildable intermediates under the
target DerivedData tree before saving a CI cache (keeps Build/Products).
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

  # Index / symbol stores are rebuildable and dominate cache size.
  # Keep Build/Products, ModuleCache, and SourcePackages so --no-build stays warm.
  # Intermediates are only needed for incremental compilation and add substantial
  # transfer cost to every fan-out test job.
  rm -rf \
    "$target/Build/Intermediates.noindex" \
    "$target/Build/ProfileData" \
    "$target/Index.noindex" \
    "$target/Index" \
    "$target/SymbolCache" \
    "$target/SDKStatCaches.noindex" \
    "$target/CompilationCache.noindex" \
    "$target/Logs" \
    2>/dev/null || true

  # Per-package DerivedData tenants (parallel package builds).
  if [[ -d "$target/packages" ]]; then
    find "$target/packages" -mindepth 1 -maxdepth 1 -type d -print0 \
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
  find "$target/TestResults" -type d -name '*.xcresult' -prune -exec rm -rf {} + 2>/dev/null || true
}

if [[ "$CI_MODE" == "true" ]]; then
  prune_derived_data_bulk "$DERIVED_DATA_PATH"
else
  echo "=== Skipping Intermediate/compilation-cache wipe (pass --ci or set CI=true) ==="
fi

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
