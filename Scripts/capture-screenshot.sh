#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SCREENSHOTS_DIR="$PWD/.DerivedData/Screenshots"
mkdir -p "$SCREENSHOTS_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_PATH="${1:-$SCREENSHOTS_DIR/simulator-$TIMESTAMP.png}"

mkdir -p "$(dirname "$OUTPUT_PATH")"
xcrun simctl io booted screenshot "$OUTPUT_PATH"
echo "$OUTPUT_PATH"
