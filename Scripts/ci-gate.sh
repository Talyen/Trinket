#!/usr/bin/env bash
# Fast local gate matching CI's Generate and style job (no unit/smoke).
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh

FAST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast) FAST=true ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/ci-gate.sh [--fast]

Full gate (default): generation, style, module boundaries, script regressions,
Swift Testing policy, release-note validation, and artwork budget.

--fast skips generation and style (already covered by handoff/push) and runs
only the cheap full-tree slices: module boundaries, Swift Testing migration,
release-note validation, and artwork budget.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$FAST" == true ]]; then
  # shellcheck source=lib/cheap-slices.sh
  source Scripts/lib/cheap-slices.sh
  echo "=== Cheap slices (boundaries, Swift Testing, release notes, artwork-budget) ==="
  trinket_run_cheap_slices
  echo "=== Fast gate checks passed ==="
  exit 0
fi

echo "=== Ensure pinned tools ==="
trinket_require_pinned_tools

echo "=== Generating Xcode project / catalogs ==="
./Scripts/generate.sh --force-xcodegen

# Align with build.sh / test.sh stamp so subsequent test.sh skips a second generate.
# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
trinket_run_env_init
# shellcheck source=build-inputs.sh
source ./Scripts/build-inputs.sh
touch_generate_stamp "$RESULTS_DIR"

echo "=== Assert generated output is committed ==="
if ! ./Scripts/assert-generated-output.sh; then
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::error::Generated output drifted. Run ./Scripts/generate.sh and commit Trinket.xcodeproj + Generated catalogs."
  fi
  exit 1
fi

# Order: style → boundaries → script checks → Swift Testing → release notes → artwork budget
# (CI gate.yml calls this script).
echo "=== Style check ==="
./Scripts/test.sh style

echo "=== Module boundary check ==="
./Scripts/check-module-boundaries.sh

echo "=== Script checks ==="
./Scripts/test-scripts.sh

echo "=== Swift Testing migration gate ==="
./Scripts/check-swift-testing-migration.sh

echo "=== Validate release notes config ==="
./Scripts/release-notes.sh validate

echo "=== Gate checks passed ==="
