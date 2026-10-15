#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  exec python3 Scripts/check-build-cache-paths.py --help
fi
# Source the live owner so computed package roots and freshness drift stay observable.
source Scripts/build-freshness.sh
exec python3 Scripts/check-build-cache-paths.py \
  --cache-roots "${TRINKET_CACHE_REQUIRED_ROOTS[@]}" --inputs "${build_input_paths[@]}" \
  --required-inputs "${TRINKET_BUILD_ROOTS[@]}" "${TRINKET_PROJECT_INPUTS[@]}" --packages "${TRINKET_TEST_PACKAGES[@]}"
