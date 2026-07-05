#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
./Scripts/generate.sh

# shellcheck source=ensure-simulator.sh
source ./Scripts/ensure-simulator.sh
ensure_test_simulator

xcodebuild build \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination "$SIMULATOR_DESTINATION"

