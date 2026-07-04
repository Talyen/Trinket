#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

EXPECTED_VERSION="0.61.1"
SOURCE_DIRS=(Trinket TrinketTests TrinketUITests)

if ! command -v swiftformat &>/dev/null; then
  echo "SwiftFormat is not installed. Install via: brew install swiftformat"
  exit 1
fi

INSTALLED_VERSION="$(swiftformat --version)"
if [[ "$INSTALLED_VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "SwiftFormat version mismatch: expected $EXPECTED_VERSION, found $INSTALLED_VERSION"
  echo "Install the expected version via: brew install swiftformat"
  exit 1
fi

MODE="apply"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lint)
      MODE="lint"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--lint]"
      exit 1
      ;;
  esac
done

if [[ "$MODE" == "lint" ]]; then
  swiftformat "${SOURCE_DIRS[@]}" --lint
else
  swiftformat "${SOURCE_DIRS[@]}"
fi
