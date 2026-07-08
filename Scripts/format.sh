#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=tool-versions.env
source Scripts/tool-versions.env
EXPECTED_VERSION="$SWIFTFORMAT_VERSION"
SOURCE_DIRS=(
  Trinket
  TrinketTests
  TrinketUITests
  Packages/TrinketCore/Sources
  Packages/TrinketContent/Sources
  Packages/BattleEngine/Sources
  Packages/TrinketPersistence/Sources
  Packages/TrinketDesignSystem/Sources
)

# Prefer pinned .tools binary when present.
if [[ -x .tools/swiftformat ]]; then
  export PATH="$PWD/.tools:$PATH"
fi

if ! command -v swiftformat &>/dev/null; then
  echo "SwiftFormat is not installed."
  echo "Install the pinned version via: ./Scripts/ensure-ci-tools.sh"
  echo "Or: brew install swiftformat (must be $EXPECTED_VERSION)"
  exit 1
fi

INSTALLED_VERSION="$(swiftformat --version)"
if [[ "$INSTALLED_VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "SwiftFormat version mismatch: expected $EXPECTED_VERSION, found $INSTALLED_VERSION"
  echo "Install the expected version via: ./Scripts/ensure-ci-tools.sh"
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
