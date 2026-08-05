#!/usr/bin/env bash
# Fast local gate matching CI's Generate and style job (no unit/smoke).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Ensure pinned tools ==="
./Scripts/ensure-ci-tools.sh
export PATH="$PWD/.tools:$PATH"
export TRINKET_REQUIRE_PINNED_TOOLS=1

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

# Order: style → boundaries → swift-testing → release-notes (CI gate.yml calls this script).
echo "=== Style check ==="
./Scripts/test.sh style

echo "=== Module boundary check ==="
./Scripts/check-module-boundaries.sh

echo "=== Build input / cache-key path alignment ==="
./Scripts/check-build-cache-paths.sh

echo "=== Swift Testing migration gate ==="
./Scripts/check-swift-testing-migration.sh

echo "=== Validate release notes config ==="
./Scripts/release-notes.sh validate

echo "=== Gate checks passed ==="
