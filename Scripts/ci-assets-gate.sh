#!/usr/bin/env bash
# Asset codegen gate matching CI's assets-gate job (locale-stable regenerate).
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh

echo "=== Ensure pinned tools ==="
trinket_require_pinned_tools

echo "=== Generating assets ==="
./Scripts/generate.sh --assets

assert_assets_committed() {
  local label="$1"
  echo "=== Assert generated assets are committed ($label) ==="
  if ./Scripts/assert-generated-output.sh --assets; then
    return 0
  fi
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::error::Generated assets drifted ($label). Run ./Scripts/generate.sh --assets and commit catalogs/assets."
  fi
  exit 1
}

assert_assets_committed "C"

# generate.sh exports LC_ALL=C; re-run under en_US.UTF-8 to catch collation drift.
echo "=== Locale-stable asset regenerate (en_US.UTF-8) ==="
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 ./Scripts/generate.sh --assets
assert_assets_committed "en_US.UTF-8"

echo "=== Asset gate checks passed ==="
