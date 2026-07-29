#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Gate (generate, style, boundaries) ==="
./Scripts/ci-gate.sh

# Gate already ran generate; avoid a second generate in build/test wrappers.
export SKIP_GENERATE=1

echo ""
echo "=== Build for testing (app + packages) ==="
./Scripts/build-for-testing.sh

echo ""
echo "=== Unit tests ==="
./Scripts/test.sh unit --no-build

echo ""
echo "=== Unit timing report ==="
./Scripts/test-timing.sh report --mode unit --last 1 --top 10

echo ""
echo "=== Quick smoke UI canary ==="
./Scripts/test.sh smoke --no-build

echo ""
echo "=== Smoke timing report ==="
./Scripts/test-timing.sh report --mode smoke --last 1 --top 10

echo ""
echo "=== All checks passed ==="
