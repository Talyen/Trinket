#!/usr/bin/env bash
# Shared helpers for test.sh / build-for-testing.sh --no-build stamp files.

build_stamp_key() {
  local fingerprint="$1"
  printf '%s' "$fingerprint" | shasum -a 256 | awk '{print $1}'
}

build_stamp_path() {
  local results_dir="$1"
  local fingerprint="$2"
  local run_key
  run_key="$(build_stamp_key "$fingerprint")"
  printf '%s/.last-build-%s.stamp' "$results_dir" "$run_key"
}

touch_build_stamp() {
  local results_dir="$1"
  local fingerprint="$2"
  local stamp
  stamp="$(build_stamp_path "$results_dir" "$fingerprint")"
  mkdir -p "$results_dir"
  touch "$stamp"
  # Optional: build-inputs.sh defines the snapshot helper when sourced.
  if declare -F record_build_input_git_snapshot >/dev/null 2>&1; then
    record_build_input_git_snapshot "$stamp"
  fi
}

package_test_scheme() {
  case "$1" in
    BattleEngine) printf '%s\n' 'BattleEngine-Package' ;;
    TrinketContent) printf '%s\n' 'TrinketContent-Package' ;;
    TrinketFeatureSupport) printf '%s\n' 'TrinketFeatureSupport-Package' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# Package schemes get their own DerivedData tenant so builds can run in parallel
# without contending on a shared build.db. App builds keep DERIVED_DATA_PATH.
package_derived_data_path() {
  local package="$1"
  printf '%s/packages/%s' "${DERIVED_DATA_PATH:?}" "$package"
}

# SPM package schemes still emit XCBuildData under Packages/.DerivedData when only
# -derivedDataPath is set, racing parallel package builds on one build.db. Pin
# products/intermediates into the per-package tenant alongside -derivedDataPath.
package_symroot() {
  printf '%s/Build/Products' "${1:?}"
}

package_objroot() {
  printf '%s/Build/Intermediates.noindex' "${1:?}"
}

package_shared_precomps_dir() {
  printf '%s/Build/Intermediates.noindex/PrecompiledHeaders' "${1:?}"
}

# Fingerprints stamped after build-for-testing so test.sh --no-build can reuse
# products. App-only builds omit unit/package/all (those need package schemes).
# shellcheck disable=SC2034
TRINKET_BUILD_FINGERPRINTS_APP=(
  smoke
  smoke_SmokeHomesteadTests
  smoke_SmokeBattleTests
  smoke_SmokeCollectionTests
  smoke_SmokePlayTests
  smoke_SmokeShopTests
  smoke-full
  ui
  ui_BattleFlowUITests
  ui_TabNavigationUITests_CollectionSearchUITests
  ui_PlayMapUITests_MysteryRecruitUITests
)

# shellcheck disable=SC2034
TRINKET_BUILD_FINGERPRINTS_FULL=(
  unit
  unit_TrinketTests
  "${TRINKET_BUILD_FINGERPRINTS_APP[@]}"
  all
)
