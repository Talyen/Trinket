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
SOURCE_DIRS=("${SWIFT_SOURCE_DIRS[@]}")

trinket_require_pinned_version swiftformat "$SWIFTFORMAT_VERSION" --version

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
