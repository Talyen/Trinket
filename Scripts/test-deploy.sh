#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Full deploy gate. Runs the same checks as ci-locally.sh plus the full UI
# suite. Intended for pre-merge / nightly runs, not the local iteration loop.
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
    --fast|-f)
      echo "Warning: --fast is deprecated; use --no-build." >&2
      NO_BUILD_FLAG+=("--no-build")
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
echo "=== Style check ==="
./Scripts/test.sh style

echo ""
echo "=== Unit tests ==="
./Scripts/test.sh "${NO_BUILD_FLAG[@]}" unit

echo ""
echo "=== Full UI tests ==="
./Scripts/test.sh --no-build ui
./Scripts/test-timing.sh assert-budget --mode ui --max-wall 720

echo ""
echo "=== All deploy checks passed ==="
