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

echo ""
echo "=== Smoke UI tests ==="
./Scripts/test.sh smoke

echo ""
echo "=== All checks passed ==="
