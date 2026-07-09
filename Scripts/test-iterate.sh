#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Fast UI iteration: build once, run a smoke class, then optional exhaustive class.
#
# Examples:
#   ./Scripts/test-iterate.sh SmokeCollectionTests
#   ./Scripts/test-iterate.sh SmokeCollectionTests TabNavigationUITests
#   ./Scripts/test-iterate.sh BattleFlowUITests --no-build

NO_BUILD_FLAG=()
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      NO_BUILD_FLAG+=("$1")
      shift
      ;;
    *)
      TARGETS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Usage: $0 <SmokeClass> [ExhaustiveClass] [--no-build]"
  exit 1
fi

FIRST_TARGET="${TARGETS[0]}"
REMAINING=("${TARGETS[@]:1}")

echo "=== UI iteration: $FIRST_TARGET ==="
if [[ "$FIRST_TARGET" == Smoke* ]]; then
  ./Scripts/test.sh "${NO_BUILD_FLAG[@]}" smoke "$FIRST_TARGET"
else
  ./Scripts/test.sh "${NO_BUILD_FLAG[@]}" ui "$FIRST_TARGET"
fi

for target in "${REMAINING[@]}"; do
  echo ""
  echo "=== UI iteration: $target ==="
  if [[ "$target" == Smoke* ]]; then
    ./Scripts/test.sh --no-build smoke "$target"
  else
    ./Scripts/test.sh --no-build ui "$target"
  fi
done

echo ""
echo "=== UI iteration complete ==="
