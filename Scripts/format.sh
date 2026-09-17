#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
trinket_prepend_pinned_tools

# shellcheck source=tool-versions.env
source Scripts/tool-versions.env
# shellcheck source=format-dirs.env
source Scripts/format-dirs.env
SOURCE_DIRS=("${SWIFT_SOURCE_DIRS[@]}")

MODE="apply"
PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lint)
      MODE="lint"
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--lint] [-- path...]"
      echo "Apply SwiftFormat to package/app sources (or --lint to check only)."
      exit 0
      ;;
    --)
      shift
      PATHS+=("$@")
      break
      ;;
    -*)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--lint] [-- path...]" >&2
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

trinket_require_pinned_version swiftformat "$SWIFTFORMAT_VERSION" --version

if [[ "$MODE" == "lint" ]]; then
  swiftformat "${FORMAT_TARGETS[@]}" --lint
else
  swiftformat "${FORMAT_TARGETS[@]}"
fi
