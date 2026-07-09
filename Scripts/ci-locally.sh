#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Gate (generate, style, boundaries) ==="
./Scripts/ci-gate.sh

# Gate already ran generate; avoid a second generate in test.sh.
export SKIP_GENERATE=1

echo ""
echo "=== Unit tests ==="
./Scripts/test.sh unit

echo ""
echo "=== Unit timing budget ==="
./Scripts/test-timing.sh assert-budget --mode unit --max-wall 60 --skip-if-missing

echo ""
echo "=== Quick smoke UI canary ==="
./Scripts/test.sh smoke

echo ""
echo "=== Smoke timing budget ==="
./Scripts/test-timing.sh assert-budget --mode smoke --max-wall 30 --skip-if-missing

echo ""
echo "=== All checks passed ==="
