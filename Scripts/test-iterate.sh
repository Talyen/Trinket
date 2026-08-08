#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# The first test invocation owns the build.  Subsequent classes use the same
# app/UI test bundles even when their mode or target fingerprint differs.
# Mark those fingerprints only after the first invocation succeeds so
# test.sh's --no-build freshness guard can recognize this intentional reuse.
source ./Scripts/run-env.sh
source ./Scripts/build-stamp.sh

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

trinket_run_env_init
ITERATION_RESULTS_DIR="${RESULTS_DIR:-$PWD/.DerivedData/TestResults}"

FIRST_TARGET="${TARGETS[0]}"
REMAINING=("${TARGETS[@]:1}")

echo "=== UI iteration: $FIRST_TARGET ==="
if [[ "$FIRST_TARGET" == Smoke* ]]; then
  ./Scripts/test.sh "${NO_BUILD_FLAG[@]}" smoke "$FIRST_TARGET"
else
  ./Scripts/test.sh "${NO_BUILD_FLAG[@]}" ui "$FIRST_TARGET"
fi

for target in "${REMAINING[@]}"; do
  # Mode-level stamps let targeted --no-build runs fall back to the mode stamp
  # even when the first iteration ran in a different mode (smoke vs ui).
  if [[ "$target" == Smoke* ]]; then
    touch_build_stamp "$ITERATION_RESULTS_DIR" "smoke"
  else
    touch_build_stamp "$ITERATION_RESULTS_DIR" "ui"
  fi
done

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
