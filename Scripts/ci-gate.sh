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
mkdir -p "$RESULTS_DIR"
touch "$RESULTS_DIR/.last-generate.stamp"

echo "=== Assert generated output is committed ==="
./Scripts/assert-generated-output.sh

echo "=== Module boundary check ==="
./Scripts/check-module-boundaries.sh

echo "=== Swift Testing migration gate ==="
./Scripts/check-swift-testing-migration.sh

echo "=== Style check ==="
./Scripts/test.sh style

echo "=== Validate release notes config ==="
./Scripts/release-notes.sh validate

echo "=== Gate checks passed ==="
