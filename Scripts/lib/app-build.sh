#!/usr/bin/env bash
# Shared app xcodebuild arguments for compile and build-for-testing runners.
# Callers select the action; the fourth argument selects configuration (Debug by default).

trinket_set_local_simulator_architecture_args() {
  TRINKET_LOCAL_SIMULATOR_ARCHITECTURE_ARGS=()
  if [[ "$1" == iphonesimulator && "$2" == Debug \
    && "${CI:-}" != true && "${GITHUB_ACTIONS:-}" != true ]]; then
    TRINKET_LOCAL_SIMULATOR_ARCHITECTURE_ARGS=("ARCHS=$(uname -m)")
  fi
}

trinket_set_app_xcodebuild_args() {
  local derived_data_path="$1"
  TRINKET_APP_XCODEBUILD_ARGS=(
    -project Trinket.xcodeproj
    -scheme Trinket
    -configuration "${4:-Debug}"
    -sdk "${2:-iphonesimulator}"
    -destination "${3:-generic/platform=iOS Simulator}"
    -derivedDataPath "$derived_data_path"
    -parallelizeTargets
    -disableAutomaticPackageResolution
    "SYMROOT=$derived_data_path/Build/Products"
    "OBJROOT=$derived_data_path/Build/Intermediates.noindex"
    "SHARED_PRECOMPS_DIR=$derived_data_path/Build/Intermediates.noindex/PrecompiledHeaders"
  )
  if [[ "${2:-iphonesimulator}" == iphonesimulator ]]; then
    TRINKET_APP_XCODEBUILD_ARGS+=(CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=-)
  fi
  trinket_set_local_simulator_architecture_args "${2:-iphonesimulator}" "${4:-Debug}"
  if (( ${#TRINKET_LOCAL_SIMULATOR_ARCHITECTURE_ARGS[@]} )); then
    TRINKET_APP_XCODEBUILD_ARGS+=("${TRINKET_LOCAL_SIMULATOR_ARCHITECTURE_ARGS[@]}")
  fi
}
