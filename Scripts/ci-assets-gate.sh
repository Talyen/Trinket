#!/usr/bin/env bash
# Asset codegen gate matching CI's assets-gate job (locale-stable regenerate).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Ensure pinned tools ==="
./Scripts/ensure-ci-tools.sh
export PATH="$PWD/.tools:$PATH"
export TRINKET_REQUIRE_PINNED_TOOLS=1

echo "=== Generating assets ==="
./Scripts/generate.sh --assets

echo "=== Assert generated assets are committed ==="
if ! ./Scripts/assert-generated-output.sh --assets; then
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::error::Generated assets drifted. Run ./Scripts/generate.sh --assets and commit catalogs/assets."
  fi
  exit 1
fi

# generate.sh exports LC_ALL=C; re-run under en_US.UTF-8 to catch collation drift.
echo "=== Locale-stable asset regenerate (en_US.UTF-8) ==="
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 ./Scripts/generate.sh --assets
if ! ./Scripts/assert-generated-output.sh --assets; then
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::error::Generated assets drifted under en_US.UTF-8. Fix locale-sensitive sort/hash ordering."
  fi
  exit 1
fi

echo "=== Asset gate checks passed ==="
