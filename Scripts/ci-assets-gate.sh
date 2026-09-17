#!/usr/bin/env bash
# Asset codegen gate matching CI's assets-gate job (locale-stable regenerate).
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: $0"
  echo "Asset codegen gate matching CI's assets-gate job (locale-stable regenerate)."
  exit 0
fi

trinket_gate_ensure_tools

trinket_log_section "Generating assets"
./Scripts/generate.sh --assets

assert_assets_committed() {
  local label="$1"
  trinket_log_section "Assert generated assets are committed ($label)"
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
trinket_log_section "Locale-stable asset regenerate (en_US.UTF-8)"
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 ./Scripts/generate.sh --assets
assert_assets_committed "en_US.UTF-8"

trinket_log_section "Checking asset and manifest bi-directional integrity"
python3 ./Scripts/check-unused-assets.py

trinket_log_section "Asset gate checks passed"


