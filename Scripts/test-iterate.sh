#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

# UI iteration loop. Defaults to the smoke tier; pass extra test class/method
# arguments to also run a targeted full-UI test alongside smoke.
#
# Examples:
#   ./Scripts/test-iterate.sh
#   ./Scripts/test-iterate.sh SmokeCollectionTests
#   ./Scripts/test-iterate.sh SmokeCollectionTests/testHeroDetailOpens
#   ./Scripts/test-iterate.sh Collection/TabNavigationUITests
#   ./Scripts/test-iterate.sh --fast SmokeCollectionTests

FAST_FLAG=()
TARGETS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast|-f)
      FAST_FLAG+=("$1")
      shift
      ;;
    *)
      TARGETS+=("$1")
      shift
      ;;
  esac
done

echo "=== Smoke UI tests ==="
./Scripts/test.sh "${FAST_FLAG[@]}" smoke

if [[ ${#TARGETS[@]} -gt 0 ]]; then
  echo ""
  echo "=== Targeted UI test(s): ${TARGETS[*]} ==="
  ./Scripts/test.sh "${FAST_FLAG[@]}" ui "${TARGETS[@]}"
fi
