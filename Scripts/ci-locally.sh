#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

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
echo "=== Unit tests ==="
./Scripts/test.sh unit

echo ""
echo "=== Smoke UI tests ==="
./Scripts/test.sh smoke

echo ""
echo "=== All checks passed ==="
