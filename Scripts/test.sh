#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

# Parse arguments
MODE="unit"
NO_BUILD=false
USED_FAST_ALIAS=false
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    ui|--ui)
      MODE="ui"
      shift
      ;;
    all|--all)
      MODE="all"
      shift
      ;;
    style|--style)
      MODE="style"
      shift
      ;;
    unit|--unit)
      MODE="unit"
      shift
      ;;
    smoke|--smoke)
      MODE="smoke"
      shift
      ;;
    include-sync|--include-sync)
      echo "Warning: --include-sync is deprecated; sync coordinator tests now run in default unit mode." >&2
      shift
      ;;
    no-build|--no-build)
      NO_BUILD=true
      shift
      ;;
    fast|--fast|-f)
      NO_BUILD=true
      USED_FAST_ALIAS=true
      shift
      ;;
    *)
      TARGETS+=("$1")
      shift
      ;;
  esac
done

if [[ "$MODE" == "style" ]]; then
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Target filters are not supported for style mode."
    echo "Usage: $0 [unit | ui | all | style | smoke] [--no-build] [TestClass[/testMethod] ...]"
    exit 1
  fi

  ./Scripts/format.sh --lint
  ./Scripts/lint.sh
  ./Scripts/check-ui-style.sh
  exit 0
fi

if [[ "$NO_BUILD" == "false" && "${SKIP_GENERATE:-0}" != "1" ]]; then
  # Always run generate to validate manifests, refresh codegen, and update XcodeGen.
  ./Scripts/generate.sh
fi

# shellcheck source=ensure-simulator.sh
source "$SCRIPT_DIR/ensure-simulator.sh"

run_xcodebuild() {
  local attempt=1
  local max_attempts=2
  local exit_code=0

  while (( attempt <= max_attempts )); do
    if "$@"; then
      return 0
    fi
    exit_code=$?
    if [[ "$exit_code" -eq 70 && "$attempt" -lt "$max_attempts" ]]; then
      echo "xcodebuild destination error (exit 70); re-preparing simulator and retrying..." >&2
      ensure_test_simulator force
      ((attempt++))
      continue
    fi
    return "$exit_code"
  done

  return "$exit_code"
}

ui_parallel_workers() {
  local default_workers="$1"

  if [[ -n "${UI_PARALLEL_WORKERS:-}" ]]; then
    echo "$UI_PARALLEL_WORKERS"
  else
    echo "$default_workers"
  fi
}

configure_ui_parallelism() {
  local worker_count="$1"

  if (( worker_count > 1 )); then
    ensure_test_simulator
    delete_xcode_parallel_clones "$SIMULATOR_NAME"
    ensure_simulator_pool "$worker_count"
    PARALLEL_FLAGS=(
      -parallel-testing-enabled YES
      -maximum-parallel-testing-workers "$worker_count"
    )
  else
    ensure_test_simulator
    PARALLEL_FLAGS=(-parallel-testing-enabled NO)
  fi
}

# Determine xcodebuild test target constraints and parallel testing flags using arrays to prevent zsh argument splitting issues
TEST_TARGET_FLAG=()
PARALLEL_FLAGS=()
if [[ "$MODE" == "unit" ]]; then
  TEST_TARGET_FLAG=(-testPlan Unit)
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Running targeted unit tests..."
    for target in "${TARGETS[@]}"; do
      if [[ "$target" == TrinketTests* ]]; then
        TEST_TARGET_FLAG+=("-only-testing:$target")
      else
        TEST_TARGET_FLAG+=("-only-testing:TrinketTests/$target")
      fi
    done
  else
    echo "Running only unit tests (TrinketTests)..."
    TEST_TARGET_FLAG=(-testPlan Unit -only-testing:TrinketTests)
  fi
elif [[ "$MODE" == "smoke" ]]; then
  TEST_TARGET_FLAG=(-testPlan Smoke)
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Running targeted UI smoke tests via Smoke test plan..."
    for target in "${TARGETS[@]}"; do
      if [[ "$target" == TrinketUITests* ]]; then
        TEST_TARGET_FLAG+=("-only-testing:$target")
      else
        TEST_TARGET_FLAG+=("-only-testing:TrinketUITests/$target")
      fi
    done
  else
    echo "Running UI smoke tests via Smoke test plan..."
  fi
  default_workers=$([[ ${#TARGETS[@]} -gt 0 ]] && echo 1 || echo 3)
  UI_PARALLEL_WORKERS="$(ui_parallel_workers "$default_workers")"
  configure_ui_parallelism "$UI_PARALLEL_WORKERS"
elif [[ "$MODE" == "ui" ]]; then
  TEST_TARGET_FLAG=(-testPlan FullUI)
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Running targeted UI tests..."
    for target in "${TARGETS[@]}"; do
      if [[ "$target" == TrinketUITests* ]]; then
        TEST_TARGET_FLAG+=("-only-testing:$target")
      else
        TEST_TARGET_FLAG+=("-only-testing:TrinketUITests/$target")
      fi
    done
  else
    echo "Running only UI tests (TrinketUITests)..."
    TEST_TARGET_FLAG=(-testPlan FullUI -only-testing:TrinketUITests)
  fi
  default_workers=$([[ ${#TARGETS[@]} -gt 0 ]] && echo 1 || echo 3)
  UI_PARALLEL_WORKERS="$(ui_parallel_workers "$default_workers")"
  configure_ui_parallelism "$UI_PARALLEL_WORKERS"
else
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Target filters are only supported for unit, ui, or smoke mode."
    echo "Usage: $0 [unit | ui | all | style | smoke] [--no-build] [TestClass[/testMethod] ...]"
    exit 1
  fi
  echo "Running all tests via Xcode Test Plan..."
  TEST_TARGET_FLAG=(-testPlan Integration)
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
fi

mkdir -p "$RESULTS_DIR"
RESULT_BUNDLE_PATH="$RESULTS_DIR/$MODE.xcresult"
rm -rf "$RESULT_BUNDLE_PATH"

ACTION="test"
RUN_FINGERPRINT="$MODE"
for target in "${TARGETS[@]}"; do
  RUN_FINGERPRINT+="_$target"
done
RUN_KEY="$(printf "%s" "$RUN_FINGERPRINT" | tr -c '[:alnum:]_.-' '_')"
BUILD_STAMP="$RESULTS_DIR/.last-build-$RUN_KEY.stamp"

assert_no_build_is_fresh() {
  if [[ "$USED_FAST_ALIAS" == "true" ]]; then
    echo "Warning: --fast is deprecated; use --no-build for test-without-building reruns." >&2
  fi

  echo "Running without building. This only reruns the previously built '$RUN_FINGERPRINT' test binary."

  if [[ ! -f "$BUILD_STAMP" ]]; then
    echo "No prior built test stamp found for '$RUN_FINGERPRINT'. Run without --no-build first." >&2
    exit 1
  fi

  local built_app="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app"
  if [[ ! -d "$built_app" ]]; then
    echo "Built app is missing from DerivedData. Run without --no-build first." >&2
    exit 1
  fi

  local newer_files=()
  local source_roots=(Trinket TrinketTests TrinketUITests Packages/TrinketCore Packages/TrinketContent Packages/BattleEngine Packages/TrinketPersistence Packages/TrinketDesignSystem)
  local root
  for root in "${source_roots[@]}"; do
    if [[ -d "$root" ]]; then
      while IFS= read -r file; do
        newer_files+=("$file")
        if [[ ${#newer_files[@]} -ge 10 ]]; then
          break 2
        fi
      done < <(find "$root" -type f \( -name "*.swift" -o -name "*.plist" -o -name "*.xctestplan" \) -newer "$BUILD_STAMP" -print)
    fi
  done

  local project_files=(project.yml Package.resolved)
  local file
  for file in "${project_files[@]}"; do
    if [[ -f "$file" && "$file" -nt "$BUILD_STAMP" ]]; then
      newer_files+=("$file")
    fi
  done

  if [[ ${#newer_files[@]} -gt 0 ]]; then
    echo "--no-build refused because sources changed after the last built '$RUN_FINGERPRINT' test binary:" >&2
    for file in "${newer_files[@]}"; do
      echo "  $file" >&2
    done
    echo "Run without --no-build to rebuild app and test bundles." >&2
    exit 1
  fi
}

if [[ "$NO_BUILD" == "true" ]]; then
  assert_no_build_is_fresh
  ACTION="test-without-building"
fi

run_package_tests() {
  local xcodebuild_action="$1"
  local packages=(TrinketCore TrinketContent BattleEngine TrinketPersistence TrinketDesignSystem)
  local pool_size=${#packages[@]}
  local package
  local index=0
  local pids=()
  local failed=0
  local max_seconds=0

  ensure_simulator_pool "$pool_size"

  for package in "${packages[@]}"; do
    local udid="${SIMULATOR_POOL_UDIDS[$((index + 1))]}"
    local destination
    destination="$(destination_for_udid "$udid")"
    local wall_file="$RESULTS_DIR/.${package}-wall.seconds"

    (
      echo "Running $package package tests on $udid..."
      SECONDS=0
      cd "Packages/$package"
      xcodebuild "$xcodebuild_action" \
        -scheme "$package" \
        -destination "$destination" \
        -derivedDataPath "$DERIVED_DATA_PATH/${package}Package"
      echo "$SECONDS" >"$wall_file"
    ) &
    pids+=($!)
    ((index++))
  done

  for pid in "${pids[@]}"; do
    wait "$pid" || failed=1
  done

  for package in "${packages[@]}"; do
    local wall_file="$RESULTS_DIR/.${package}-wall.seconds"
    if [[ -f "$wall_file" ]]; then
      local seconds
      seconds="$(<"$wall_file")"
      (( seconds > max_seconds )) && max_seconds=$seconds
      rm -f "$wall_file"
    fi
  done

  TEST_WALL_SECONDS=$((TEST_WALL_SECONDS + max_seconds))
  return "$failed"
}

TEST_WALL_SECONDS=0
SECONDS=0

if [[ "$MODE" == "unit" ]]; then
  ensure_test_simulator
fi

run_xcodebuild xcodebuild "$ACTION" \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination "$SIMULATOR_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  "${TEST_TARGET_FLAG[@]}" \
  "${PARALLEL_FLAGS[@]}"

TEST_WALL_SECONDS=$SECONDS

if [[ "$MODE" == "unit" && ${#TARGETS[@]} -eq 0 ]]; then
  echo "Running package tests in parallel..."
  run_package_tests "$ACTION" || exit 1
fi

if [[ "$NO_BUILD" == "false" ]]; then
  touch "$BUILD_STAMP"
fi

if [[ -d "$RESULT_BUNDLE_PATH" ]]; then
  ./Scripts/test-timing.sh record \
    --mode "$MODE" \
    --wall "$TEST_WALL_SECONDS" \
    --xcresult "$RESULT_BUNDLE_PATH" \
    $([[ "$NO_BUILD" == "true" ]] && echo --no-build) \
    "${TARGETS[@]}"
  echo ""
  echo "Timing recorded. Hotspots: ./Scripts/test-timing.sh"
fi
