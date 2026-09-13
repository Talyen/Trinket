#!/usr/bin/env bash
# Shared app xcodebuild arguments for compile and build-for-testing runners.
# The action (build/build-for-testing) and optional configuration flags stay in
# each command so its contract remains visible at the call site.

trinket_set_app_xcodebuild_args() {
  local derived_data_path="$1"
  TRINKET_APP_XCODEBUILD_ARGS=(
    -project Trinket.xcodeproj
    -scheme Trinket
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
}
