#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

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

echo "=== Generating Xcode project ==="
./Scripts/generate.sh

echo ""
echo "=== Assert generated output is committed ==="
./Scripts/assert-generated-output.sh

echo ""
echo "=== Module boundary check ==="
./Scripts/check-module-boundaries.sh

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
