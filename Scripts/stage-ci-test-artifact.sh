#!/usr/bin/env bash
# Archive test products without losing executable permissions or symlinks.
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="${1:-${DERIVED_DATA_PATH:-$PWD/.DerivedData}}"
DERIVED_DATA_PATH="$(cd "$DERIVED_DATA_PATH" && pwd)"
ARCHIVE="$DERIVED_DATA_PATH/ci-test-artifact.tar"

if [[ ! -d "$DERIVED_DATA_PATH/Build/Products" ]]; then
  echo "stage-ci-test-artifact: missing $DERIVED_DATA_PATH/Build/Products" >&2
  exit 1
fi

(
  cd "$DERIVED_DATA_PATH"
  shopt -s nullglob
  inputs=(Build/Products TestResults/.last-build-*.stamp TestResults/.last-build-*.stamp.gitstatus)
  COPYFILE_DISABLE=1 tar -cf "$ARCHIVE" "${inputs[@]}"
)
echo "=== Archived test products: $ARCHIVE ==="
du -sh "$ARCHIVE"
