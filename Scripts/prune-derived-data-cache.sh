#!/usr/bin/env bash
# Strip bulky DerivedData intermediates before CI cache save.
# Keeps Build/ products and module caches needed for test-without-building.
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="${1:-$PWD/.DerivedData}"

if [[ ! -d "$DERIVED_DATA_PATH" ]]; then
  echo "No DerivedData at $DERIVED_DATA_PATH; nothing to prune."
  exit 0
fi

echo "=== Pruning DerivedData cache bulk under $DERIVED_DATA_PATH ==="

# Index / symbol stores are rebuildable and dominate cache size.
# Keep Build/, ModuleCache, and SourcePackages so --no-build stays warm.
rm -rf \
  "$DERIVED_DATA_PATH/Index.noindex" \
  "$DERIVED_DATA_PATH/Index" \
  "$DERIVED_DATA_PATH/SymbolCache" \
  "$DERIVED_DATA_PATH/SDKStatCaches.noindex" \
  "$DERIVED_DATA_PATH/CompilationCache.noindex" \
  "$DERIVED_DATA_PATH/Logs" \
  2>/dev/null || true

# Drop xcresults from the cache blob (uploaded separately as artifacts).
find "$DERIVED_DATA_PATH/TestResults" -type d -name '*.xcresult' -prune -exec rm -rf {} + 2>/dev/null || true

echo "=== DerivedData prune complete ==="
