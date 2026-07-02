#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Generating Xcode project ==="
./Scripts/generate.sh

echo ""
echo "=== Style check ==="
./Scripts/test.sh style

echo ""
echo "=== Unit tests ==="
./Scripts/test.sh unit
./Scripts/test-timing.sh assert-budget --mode unit --max-wall 120

echo ""
echo "=== Smoke UI tests ==="
./Scripts/test.sh smoke
./Scripts/test-timing.sh assert-budget --mode smoke --max-wall 200

echo ""
echo "=== All checks passed ==="
