#!/usr/bin/env bash
# Budget policy is verified against the production values and cache function.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/check-artwork-budget.sh"
  echo "Runs the isolated PreparedArtworkCacheTests suite; broad qualification remains CI-owned."
  exit 0
fi
source Scripts/lib/verification-policy.sh
trinket_require_heavy_verification "Artwork budget behavior tests"
export TRINKET_ISOLATE=1
exec ./Scripts/test-package.sh --only-suite PreparedArtworkCacheTests TrinketFeatureSupport "$@"
