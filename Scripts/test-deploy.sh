#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

# Full deploy gate. Runs the same checks as ci-locally.sh plus the full UI
# suite. Intended for pre-merge / nightly runs, not the local iteration loop.
#
# Examples:
#   ./Scripts/test-deploy.sh
#   ./Scripts/test-deploy.sh --fast   # re-run without rebuilding

FAST_FLAG=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast|-f)
      FAST_FLAG+=("$1")
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [--fast]"
      exit 1
      ;;
  esac
done

echo "=== Generating Xcode project ==="
./Scripts/generate.sh

echo ""
echo "=== Style check ==="
./Scripts/test.sh style

echo ""
echo "=== Unit tests ==="
./Scripts/test.sh "${FAST_FLAG[@]}" unit

echo ""
echo "=== Performance tests ==="
./Scripts/test.sh "${FAST_FLAG[@]}" perf

echo ""
echo "=== Smoke UI tests ==="
./Scripts/test.sh "${FAST_FLAG[@]}" smoke

echo ""
echo "=== Full UI tests ==="
./Scripts/test.sh "${FAST_FLAG[@]}" ui

echo ""
echo "=== All deploy checks passed ==="
