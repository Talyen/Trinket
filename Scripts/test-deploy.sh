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

./Scripts/ci-gate.sh
# Prevent subsequent test.sh tiers from regenerating after the gate's force generate.
export SKIP_GENERATE=1

echo ""
echo "=== Unit tests ==="
./Scripts/test.sh "${NO_BUILD_FLAG[@]}" unit

echo ""
echo "=== Full UI tests ==="
./Scripts/test.sh "${NO_BUILD_FLAG[@]}" ui

echo ""
echo "=== All deploy checks passed ==="
