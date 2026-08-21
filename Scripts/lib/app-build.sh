#!/usr/bin/env bash
# Shared app xcodebuild arguments for compile and build-for-testing runners.
# The action (build/build-for-testing) and optional configuration flags stay in
# each command so its contract remains visible at the call site.

trinket_set_app_xcodebuild_args() {
  local derived_data_path="$1"
  TRINKET_APP_XCODEBUILD_ARGS=(
    -project Trinket.xcodeproj
    -scheme Trinket
    -sdk iphonesimulator
    -destination 'generic/platform=iOS Simulator'
    -derivedDataPath "$derived_data_path"
    -parallelizeTargets
    -disableAutomaticPackageResolution
  )
}
