#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=tool-versions.env
source Scripts/tool-versions.env
# shellcheck source=swift-source-dirs.env
source Scripts/swift-source-dirs.env
EXPECTED_VERSION="$SWIFTLINT_VERSION"
SOURCE_DIRS=("${SWIFT_SOURCE_DIRS[@]}")

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
  # Dual reporters: `xcode` keeps rule/file/line in job logs (agent-watch-ci
  # excerpts); `github-actions-logging` posts Checks annotations.
  extra_args+=(--reporter xcode --reporter github-actions-logging)
fi

if [ ${#extra_args[@]} -gt 0 ]; then
  swiftlint lint --strict "${SOURCE_DIRS[@]}" "${extra_args[@]}" "$@"
else
  swiftlint lint --strict "${SOURCE_DIRS[@]}" "$@"
fi
