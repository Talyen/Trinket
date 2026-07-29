#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
SCRIPT_DIR="$(dirname "$0")"

# shellcheck source=run-env.sh
source "$SCRIPT_DIR/run-env.sh"
trinket_run_env_init
trinket_run_env_print
# Isolated builds share a warm agent-N DerivedData tenant; no simulator boot needed
# (generic/platform destination), but init already acquired the agent slot.

source "$SCRIPT_DIR/build-stamp.sh"
# shellcheck source=build-inputs.sh
source "$SCRIPT_DIR/build-inputs.sh"
# shellcheck source=xcode-runner.sh
source "$SCRIPT_DIR/xcode-runner.sh"

QUIET=true
APP_ONLY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|verbose)
      QUIET=false
      shift
      ;;
    --quiet|quiet)
      QUIET=true
      shift
      ;;
    --app-only)
      APP_ONLY=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--verbose] [--app-only]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--verbose] [--app-only]" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$RESULTS_DIR"
prepare_generated_inputs "$RESULTS_DIR"

echo "=== build-for-testing: Trinket app and test bundles ==="
xcode_runner_prepare "build-app" "$RESULTS_DIR"
app_runner_args=(
  --label build-app
  --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH"
  --log "$XCODE_RUNNER_LOG_PATH"
  --report-prefix "$XCODE_RUNNER_REPORT_PREFIX"
)
if [[ "$QUIET" == "true" ]]; then
  app_runner_args+=(--quiet)
else
  app_runner_args+=(--verbose)
fi
xcode_runner_run "${app_runner_args[@]}" -- xcodebuild build-for-testing \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$XCODE_RUNNER_RESULT_BUNDLE_PATH"

if [[ "$APP_ONLY" == "true" ]]; then
  echo "=== build-for-testing: skipping package schemes (--app-only) ==="
  for fingerprint in "${TRINKET_BUILD_FINGERPRINTS_APP[@]}"; do
    touch_build_stamp "$RESULTS_DIR" "$fingerprint"
  done
  echo "=== build-for-testing complete (app-only) ==="
  exit 0
fi

PACKAGES=("${TRINKET_TEST_PACKAGES[@]}")

# Package schemes use per-package DerivedData tenants so they can build in
# parallel without contending on a shared build.db. App products stay in
# DERIVED_DATA_PATH; package test products live under packages/<name>/.
echo "=== build-for-testing: package schemes (parallel) ==="
package_build_token="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM:-0}"
package_output_root="$RESULTS_DIR/.deferred/package-build-$package_build_token"
mkdir -p "$package_output_root"

package_build_jobs="${#PACKAGES[@]}"
cpu_count="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
if [[ "$package_build_jobs" -gt "$cpu_count" ]]; then
  package_build_jobs="$cpu_count"
fi

printf '%s\n' "${PACKAGES[@]}" | xargs -P "$package_build_jobs" -I{} bash -c '
  set -euo pipefail
  package="$1"
  results_dir="$2"
  derived_data_path="$3"
  quiet="$4"
  output_root="$5"
  script_dir="$6"
  repo_root="$7"

  export DERIVED_DATA_PATH="$derived_data_path"

  # shellcheck source=build-stamp.sh
  source "$script_dir/build-stamp.sh"
  # shellcheck source=build-inputs.sh
  source "$script_dir/build-inputs.sh"
  # shellcheck source=xcode-runner.sh
  source "$script_dir/xcode-runner.sh"

  package_dd="$(package_derived_data_path "$package")"
  mkdir -p "$package_dd"

  xcode_runner_prepare "build-package-$package" "$results_dir"
  package_runner_args=(
    --label "build-package-$package"
    --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH"
    --log "$XCODE_RUNNER_LOG_PATH"
    --report-prefix "$XCODE_RUNNER_REPORT_PREFIX"
    --working-directory "$repo_root/Packages/$package"
  )
  if [[ "$quiet" == "true" ]]; then
    package_runner_args+=(--quiet)
  else
    package_runner_args+=(--verbose)
  fi

  status=0
  xcode_runner_run "${package_runner_args[@]}" -- xcodebuild build-for-testing \
    -scheme "$(package_test_scheme "$package")" \
    -sdk iphonesimulator \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$package_dd" \
    -resultBundlePath "$XCODE_RUNNER_RESULT_BUNDLE_PATH" \
    || status=$?

  if [[ "$status" -eq 0 ]]; then
    touch_build_stamp "$results_dir" "package_$package"
  fi
  printf "%s\n" "$status" >"$output_root/$package.status"
  exit "$status"
' _ {} "$RESULTS_DIR" "$DERIVED_DATA_PATH" "$QUIET" "$package_output_root" "$SCRIPT_DIR" "$PWD" || true

package_failed=0
for package in "${PACKAGES[@]}"; do
  status_file="$package_output_root/$package.status"
  if [[ ! -f "$status_file" ]] || [[ "$(cat "$status_file")" != "0" ]]; then
    echo "Package build failed: $package" >&2
    package_failed=1
  else
    echo "=== build-for-testing: $package ok ==="
  fi
done
if [[ "$package_failed" -ne 0 ]]; then
  exit 1
fi

for fingerprint in "${TRINKET_BUILD_FINGERPRINTS_FULL[@]}"; do
  touch_build_stamp "$RESULTS_DIR" "$fingerprint"
done

echo "=== build-for-testing complete ==="
