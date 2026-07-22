#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=build-inputs.sh
source ./Scripts/build-inputs.sh

echo "=== Ensure pinned tools ==="
./Scripts/ensure-ci-tools.sh
export PATH="$PWD/.tools:$PATH"
export TRINKET_REQUIRE_PINNED_TOOLS=1

# Full deploy gate. Runs CI gate checks plus unit and full UI tests.
# Intended for pre-merge / nightly runs, not the local iteration loop.
#
# Examples:
#   ./Scripts/test-deploy.sh
#   ./Scripts/test-deploy.sh --no-build   # re-run previously built test binaries

NO_BUILD_FLAG=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      NO_BUILD_FLAG+=("$1")
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [--no-build]"
      exit 1
      ;;
  esac
done

RESULTS_DIR="$PWD/.DerivedData/TestResults"
echo "=== Preparing generated build inputs ==="
prepare_generated_inputs "$RESULTS_DIR"
export SKIP_GENERATE=1

echo ""
echo "=== Assert generated output is committed ==="
./Scripts/assert-generated-output.sh

echo ""
echo "=== Module boundary check ==="
./Scripts/check-module-boundaries.sh

echo ""
echo "=== Swift Testing migration gate ==="
./Scripts/check-swift-testing-migration.sh

echo ""
echo "=== Style check ==="
./Scripts/test.sh style

echo ""
echo "=== Validate release notes config ==="
./Scripts/release-notes.sh validate

echo ""
echo "=== Unit tests ==="
./Scripts/test.sh "${NO_BUILD_FLAG[@]}" unit

echo ""
echo "=== Full UI tests ==="
./Scripts/test.sh "${NO_BUILD_FLAG[@]}" ui

echo ""
echo "=== All deploy checks passed ==="
