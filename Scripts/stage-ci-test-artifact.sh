#!/usr/bin/env bash
# Copy --no-build inputs into .DerivedData/ci-test-artifact for the CI fan-out
# upload. Keeps Build/Products plus optional ModuleCache/SourcePackages and
# TestResults stamps; drops package tenants and other DerivedData bulk.
set -euo pipefail

cd "$(dirname "$0")/.."

DERIVED_DATA_PATH="${1:-${DERIVED_DATA_PATH:-$PWD/.DerivedData}}"
STAGE="$DERIVED_DATA_PATH/ci-test-artifact"

if [[ ! -d "$DERIVED_DATA_PATH/Build/Products" ]]; then
  echo "stage-ci-test-artifact: missing $DERIVED_DATA_PATH/Build/Products" >&2
  exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/Build"
cp -a "$DERIVED_DATA_PATH/Build/Products" "$STAGE/Build/Products"

if [[ -d "$DERIVED_DATA_PATH/TestResults" ]]; then
  cp -a "$DERIVED_DATA_PATH/TestResults" "$STAGE/TestResults"
fi

for extra in ModuleCache.noindex ModuleCache SourcePackages; do
  if [[ -e "$DERIVED_DATA_PATH/$extra" ]]; then
    cp -a "$DERIVED_DATA_PATH/$extra" "$STAGE/$extra"
  fi
done

echo "=== Staged --no-build artifact under $STAGE ==="
du -sh "$STAGE" "$STAGE/Build/Products" 2>/dev/null || true
