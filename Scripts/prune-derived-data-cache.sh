#!/usr/bin/env bash
# Strip bulky DerivedData intermediates before CI cache save.
# Keeps Build/ products and module caches needed for test-without-building.
# Also reaps stale isolated run dirs, dead UI/sim concurrency slots, and
# orphaned one-off simulators from the legacy "Trinket Run *" naming scheme.
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="${1:-$PWD/.DerivedData}"
RUN_MAX_AGE_DAYS="${TRINKET_RUN_MAX_AGE_DAYS:-3}"
SHARED_ROOT="$PWD/.DerivedData"
# Default on: remove legacy one-off sims. Set TRINKET_PRUNE_ORPHAN_SIMULATORS=0 to skip.
PRUNE_ORPHAN_SIMS="${TRINKET_PRUNE_ORPHAN_SIMULATORS:-1}"

if [[ ! -d "$DERIVED_DATA_PATH" ]]; then
  echo "No DerivedData at $DERIVED_DATA_PATH; nothing to prune."
  exit 0
fi

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

# Delete legacy one-off simulators and accidental Trinket CI clones.
# Keeps canonical "Trinket CI" and reusable "Trinket Agent N" pool devices.
if [[ "$PRUNE_ORPHAN_SIMS" == "1" ]] && command -v xcrun >/dev/null 2>&1; then
  echo "=== Pruning orphaned Trinket Run / Trinket CI clone simulators ==="
  python3 - <<'PY'
import json, re, subprocess
payload = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True))
agent_re = re.compile(r"^Trinket Agent \d+$")
for devices in payload.get("devices", {}).values():
    for device in devices:
        name = device.get("name") or ""
        udid = device.get("udid")
        if not udid:
            continue
        delete = False
        if name.startswith("Trinket Run "):
            delete = True
        elif name.startswith("Trinket CI ") and name != "Trinket CI":
            # e.g. "Trinket CI iPhone 17 Pro 2" from old create retries
            delete = True
        elif name.startswith("Trinket Agent ") and not agent_re.match(name):
            delete = True
        if not delete:
            continue
        subprocess.call(["xcrun", "simctl", "delete", udid])
        print(f"Deleted orphan simulator: {name} ({udid})")
PY
fi

echo "=== DerivedData prune complete ==="
