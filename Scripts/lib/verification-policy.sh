#!/usr/bin/env bash
# Compiled/simulator verification belongs to CI; local overrides are deliberate diagnostics.
trinket_verification_is_lightweight() {
  [[ "${GITHUB_ACTIONS:-}" != true && "${TRINKET_ALLOW_HEAVY_LOCAL:-}" != 1 ]]
}

trinket_require_heavy_verification() {
  if trinket_verification_is_lightweight; then
    echo "$1 is CI-owned: no local compilation, simulator boot, or GPU workload was started." >&2
    echo "Use ./Scripts/handoff.sh --isolate --quiet --paths <files> for lightweight local checks." >&2
    echo "For an expressly requested local diagnostic, TRINKET_ALLOW_HEAVY_LOCAL=1 opts in." >&2
    return 2
  fi
  if [[ "${GITHUB_ACTIONS:-}" != true ]]; then
    export TRINKET_PACKAGE_TEST_JOBS=1 TRINKET_SERIAL_TESTS=1 TRINKET_MAX_CONCURRENT_UI=1
  fi
}
