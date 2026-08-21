#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
trinket_prepend_pinned_tools

# shellcheck source=tool-versions.env
source Scripts/tool-versions.env
# shellcheck source=swift-source-dirs.env
source Scripts/swift-source-dirs.env
EXPECTED_VERSION="$SWIFTFORMAT_VERSION"
SOURCE_DIRS=("${SWIFT_SOURCE_DIRS[@]}")

if ! command -v swiftformat &>/dev/null; then
  echo "SwiftFormat is not installed."
  echo "Install the pinned version via: ./Scripts/ensure-ci-tools.sh"
  echo "Or: brew install swiftformat (must be $EXPECTED_VERSION)"
  exit 1
fi

INSTALLED_VERSION="$(swiftformat --version)"
if [[ "$INSTALLED_VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "SwiftFormat version mismatch: expected $EXPECTED_VERSION, found $INSTALLED_VERSION"
  echo "Install the pinned version via: ./Scripts/ensure-ci-tools.sh"
  echo "Or bump the pin to the latest release via: ./Scripts/update-tools.sh --apply"
  exit 1
fi

MODE="apply"
PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lint)
      MODE="lint"
      shift
      ;;
    --)
      shift
      PATHS+=("$@")
      break
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: $0 [--lint] [-- path...]"
      exit 1
      ;;
    *)
      PATHS+=("$1")
      shift
      ;;
  esac
done

FORMAT_TARGETS=("${SOURCE_DIRS[@]}")
if (( ${#PATHS[@]} > 0 )); then
  FORMAT_TARGETS=("${PATHS[@]}")
fi

if [[ "$MODE" == "lint" ]]; then
  swiftformat "${FORMAT_TARGETS[@]}" --lint
else
  swiftformat "${FORMAT_TARGETS[@]}"
fi
