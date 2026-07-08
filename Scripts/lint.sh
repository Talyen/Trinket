#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=tool-versions.env
source Scripts/tool-versions.env
EXPECTED_VERSION="$SWIFTLINT_VERSION"
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
if [[ -x .tools/swiftlint ]]; then
  export PATH="$PWD/.tools:$PATH"
fi

if ! command -v swiftlint &>/dev/null; then
  echo "SwiftLint is not installed."
  echo "Install the pinned version via: ./Scripts/ensure-ci-tools.sh"
  echo "Or: brew install swiftlint (must be $EXPECTED_VERSION)"
  exit 1
fi

INSTALLED_VERSION="$(swiftlint version)"
if [[ "$INSTALLED_VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "SwiftLint version mismatch: expected $EXPECTED_VERSION, found $INSTALLED_VERSION"
  echo "Install the expected version via: ./Scripts/ensure-ci-tools.sh"
  exit 1
fi

extra_args=()
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  extra_args+=(--reporter github-actions-logging)
fi

if [ ${#extra_args[@]} -gt 0 ]; then
  swiftlint lint --strict "${SOURCE_DIRS[@]}" "${extra_args[@]}" "$@"
else
  swiftlint lint --strict "${SOURCE_DIRS[@]}" "$@"
fi
