#!/usr/bin/env bash
# Broad compiled/simulator verification belongs to CI; focused local work is explicit.
trinket_verification_is_lightweight() {
  [[ "${GITHUB_ACTIONS:-}" != true && "${TRINKET_ALLOW_HEAVY_LOCAL:-}" != 1 ]]
}

trinket_require_heavy_verification() {
  if trinket_verification_is_lightweight; then
    echo "$1 is CI-owned: no local compilation, simulator boot, or GPU workload was started." >&2
    echo "Use ./Scripts/handoff.sh --quiet for automatic task-scoped verification." >&2
    echo "Use --route static for cheap checks only, or --package <Package...> for selected packages." >&2
    echo "Focused direct wrappers also accept TRINKET_ALLOW_HEAVY_LOCAL=1." >&2
    return 2
  fi
  if [[ "${GITHUB_ACTIONS:-}" != true ]]; then
    export TRINKET_PACKAGE_TEST_JOBS=1 TRINKET_SERIAL_TESTS=1 TRINKET_MAX_CONCURRENT_UI=1
  fi
}
