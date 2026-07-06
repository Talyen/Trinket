#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"

GENERATE_STAMP="$RESULTS_DIR/.last-generate.stamp"
if [[ -f "$GENERATE_STAMP" ]]; then
  content_changed="$(find ContentManifest Scripts/content_codegen.py -newer "$GENERATE_STAMP" -print -quit 2>/dev/null)"
  project_changed=""
  if [[ -f project.yml && project.yml -nt "$GENERATE_STAMP" ]]; then
    project_changed="project.yml"
  fi
  if [[ -z "$content_changed" && -z "$project_changed" ]]; then
    echo "Content sources unchanged; skipping generate."
  else
    GENERATE_ARGS=()
    if [[ -z "$project_changed" ]]; then
      echo "=== Content manifests changed; running generate (skipping xcodegen) ==="
      GENERATE_ARGS+=(--skip-xcodegen)
    else
      echo "=== Content or project sources changed; running generate ==="
    fi
    ./Scripts/generate.sh "${GENERATE_ARGS[@]}"
  fi
else
  echo "=== Running generate ==="
  ./Scripts/generate.sh
fi
mkdir -p "$RESULTS_DIR"
touch "$GENERATE_STAMP"

# shellcheck source=ensure-simulator.sh
source ./Scripts/ensure-simulator.sh
ensure_test_simulator

xcodebuild build \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination "$SIMULATOR_DESTINATION"

