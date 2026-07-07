#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

EXPECTED_VERSION="0.65.0"
SOURCE_DIRS=(Trinket TrinketTests TrinketUITests)

if ! command -v swiftlint &>/dev/null; then
  echo "SwiftLint is not installed. Install via: brew install swiftlint"
  exit 1
fi

INSTALLED_VERSION="$(swiftlint version)"
if [[ "$INSTALLED_VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "SwiftLint version mismatch: expected $EXPECTED_VERSION, found $INSTALLED_VERSION"
  echo "Install the expected version via: brew install swiftlint"
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
