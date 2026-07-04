#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Generating Xcode project ==="
./Scripts/generate.sh

echo ""
echo "=== Module boundary check ==="
./Scripts/check-module-boundaries.sh

echo ""
echo "=== Style check ==="
./Scripts/test.sh style

echo ""
echo "=== Unit tests ==="
./Scripts/test.sh unit
./Scripts/test-timing.sh assert-budget --mode unit --max-wall 300

echo ""
echo "=== Smoke UI tests ==="
./Scripts/test.sh --no-build smoke
./Scripts/test-timing.sh assert-budget --mode smoke --max-wall 360

echo ""
echo "=== All checks passed ==="
