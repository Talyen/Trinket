#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

# shellcheck source=build-stamp.sh
source "$SCRIPT_DIR/build-stamp.sh"

# Parse arguments
MODE="unit"
NO_BUILD=false
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
    no-build|--no-build)
      NO_BUILD=true
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

mkdir -p "$RESULTS_DIR"
GENERATE_STAMP="$RESULTS_DIR/.last-generate.stamp"
if [[ "$NO_BUILD" == "false" && "${SKIP_GENERATE:-0}" != "1" ]]; then
  if [[ -f "$GENERATE_STAMP" ]]; then
    content_changed="$(find ContentManifest Scripts/content_codegen.py -newer "$GENERATE_STAMP" -print -quit 2>/dev/null)"
    project_changed=""
    if [[ -f project.yml && project.yml -nt "$GENERATE_STAMP" ]]; then
      project_changed="project.yml"
    fi
    if [[ -z "$content_changed" && -z "$project_changed" ]]; then
      echo "Content sources unchanged; skipping generate."
    else
      GENERATE_ARGS=()
      if [[ -z "$project_changed" ]]; then
        echo "=== Content manifests changed; running generate (skipping xcodegen) ==="
        GENERATE_ARGS+=(--skip-xcodegen)
      else
        echo "=== Content or project sources changed; running generate ==="
      fi
      if [[ ${#GENERATE_ARGS[@]} -gt 0 ]]; then
        ./Scripts/generate.sh "${GENERATE_ARGS[@]}"
      else
        ./Scripts/generate.sh
      fi
    fi
  else
    echo "=== Running generate ==="
    ./Scripts/generate.sh
  fi
  touch "$GENERATE_STAMP"
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

xcresult_failed() {
  local result_path="$1"
  [[ -d "$result_path" ]] || return 1
  xcrun xcresulttool get test-results summary --path "$result_path" 2>/dev/null \
    | grep -Eq '"result" : "(Failed|unknown)"'
}

# Determine xcodebuild test target constraints using arrays to prevent zsh argument splitting issues
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
  ensure_test_simulator
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
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
  ensure_test_simulator
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
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
  ensure_test_simulator
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
else
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Target filters are only supported for unit, ui, or smoke mode."
    echo "Usage: $0 [unit | ui | all | style | smoke] [--no-build] [TestClass[/testMethod] ...]"
    exit 1
  fi
  echo "Running all tests via Xcode Test Plan..."
  TEST_TARGET_FLAG=(-testPlan Integration)
  ensure_test_simulator
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
fi

mkdir -p "$RESULTS_DIR"
RESULT_BUNDLE_PATH="$RESULTS_DIR/$MODE.xcresult"
rm -rf "$RESULT_BUNDLE_PATH"

ACTION="test"
RUN_FINGERPRINT="$MODE"
if [[ ${#TARGETS[@]} -gt 0 ]]; then
  for target in "${TARGETS[@]}"; do
    RUN_FINGERPRINT+="_$target"
  done
fi
BUILD_STAMP="$(build_stamp_path "$RESULTS_DIR" "$RUN_FINGERPRINT")"

record_timing() {
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    ./Scripts/test-timing.sh record \
      --mode "$MODE" \
      --wall "$TEST_WALL_SECONDS" \
      --xcresult "$RESULT_BUNDLE_PATH" \
      $([[ "$NO_BUILD" == "true" ]] && echo --no-build) \
      "${TARGETS[@]}"
  else
    ./Scripts/test-timing.sh record \
      --mode "$MODE" \
      --wall "$TEST_WALL_SECONDS" \
      --xcresult "$RESULT_BUNDLE_PATH" \
      $([[ "$NO_BUILD" == "true" ]] && echo --no-build)
  fi
}

assert_no_build_is_fresh() {
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

  # Fast-path: if stamp is < 30s old, skip the scan — nothing changed at human speed
  local stamp_age=999
  if [[ -f "$BUILD_STAMP" ]]; then
    stamp_age=$(($(date +%s) - $(stat -f %m "$BUILD_STAMP" 2>/dev/null || echo 0)))
  fi
  if [[ "$stamp_age" -lt 30 ]]; then
    echo "Build stamp is < 30s old; sources unchanged."
    return 0
  fi

  local source_roots=(Trinket TrinketTests TrinketUITests Packages/TrinketCore Packages/TrinketContent Packages/BattleEngine Packages/TrinketPersistence Packages/TrinketDesignSystem)
  local existing_roots=()
  for root in "${source_roots[@]}"; do
    [[ -d "$root" ]] && existing_roots+=("$root")
  done
  if [[ ${#existing_roots[@]} -gt 0 ]]; then
    while IFS= read -r file; do
      newer_files+=("$file")
      if [[ ${#newer_files[@]} -ge 10 ]]; then
        break
      fi
    done < <(find "${existing_roots[@]}" -type f \( -name "*.swift" -o -name "*.plist" -o -name "*.xctestplan" \) -newer "$BUILD_STAMP" -print)
  fi

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
  local failed=0
  local max_seconds=0

  for package in "${packages[@]}"; do
    echo "Running $package package tests..."
    SECONDS=0
    local package_status=0
    local package_args=("$package" --destination "$SIMULATOR_DESTINATION")
    if [[ "$xcodebuild_action" == "test-without-building" ]]; then
      package_args=(--no-build "${package_args[@]}")
    fi
    ./Scripts/test-package.sh "${package_args[@]}" || package_status=$?
    if [[ "$package_status" -ne 0 ]]; then
      failed=1
    fi
    local elapsed=$SECONDS
    (( elapsed > max_seconds )) && max_seconds=$elapsed
  done

  TEST_WALL_SECONDS=$((TEST_WALL_SECONDS + max_seconds))
  return "$failed"
}

TEST_WALL_SECONDS=0
SECONDS=0

XCODEBUILD_EXIT_CODE=0
XCODEBUILD_ARGS=(
  "$ACTION"
  -project Trinket.xcodeproj
  -scheme Trinket
  -sdk iphonesimulator
  -destination "$SIMULATOR_DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -resultBundlePath "$RESULT_BUNDLE_PATH"
)
if [[ ${#TEST_TARGET_FLAG[@]} -gt 0 ]]; then
  XCODEBUILD_ARGS+=("${TEST_TARGET_FLAG[@]}")
fi
if [[ ${#PARALLEL_FLAGS[@]} -gt 0 ]]; then
  XCODEBUILD_ARGS+=("${PARALLEL_FLAGS[@]}")
fi

run_xcodebuild xcodebuild "${XCODEBUILD_ARGS[@]}" || XCODEBUILD_EXIT_CODE=$?

TEST_WALL_SECONDS=$SECONDS

if xcresult_failed "$RESULT_BUNDLE_PATH"; then
  XCODEBUILD_EXIT_CODE=1
fi

if [[ "$XCODEBUILD_EXIT_CODE" -ne 0 ]]; then
  if [[ -d "$RESULT_BUNDLE_PATH" ]]; then
    record_timing
    echo ""
    echo "Timing recorded. Hotspots: ./Scripts/test-timing.sh"
  fi
  exit "$XCODEBUILD_EXIT_CODE"
fi

if [[ "$MODE" == "unit" && ${#TARGETS[@]} -eq 0 ]]; then
  echo "Running package tests..."
  run_package_tests "$ACTION" || exit 1
fi

if [[ "$NO_BUILD" == "false" ]]; then
  touch "$BUILD_STAMP"
fi

if [[ -d "$RESULT_BUNDLE_PATH" ]]; then
  record_timing
  echo ""
  echo "Timing recorded. Hotspots: ./Scripts/test-timing.sh"
fi
