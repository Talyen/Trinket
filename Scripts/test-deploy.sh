#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Full deploy gate. Runs CI gate checks plus unit and full UI tests.
# Intended for pre-merge / nightly runs, not the local iteration loop.
#
# Examples:
#   ./Scripts/test-deploy.sh
#   ./Scripts/test-deploy.sh --no-build   # re-run previously built test binaries

NO_BUILD=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      NO_BUILD=true
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
# Prevent subsequent build/test wrappers from regenerating after the gate's force generate.
export SKIP_GENERATE=1

if [[ "$NO_BUILD" == "false" ]]; then
  echo ""
  echo "=== Build for testing (app + packages) ==="
  ./Scripts/build-for-testing.sh
fi

echo ""
echo "=== Unit tests ==="
./Scripts/test.sh unit --no-build

echo ""
echo "=== Full UI tests ==="
./Scripts/test.sh ui --no-build

echo ""
echo "=== All deploy checks passed ==="
