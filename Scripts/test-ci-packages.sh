#!/usr/bin/env bash
# Routine verified runs use qualified native logic; qualification/nightly retain iOS.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == --help ]]; then
  echo "Usage: $0 <Package...> (CI native/iOS dispatcher; qualification/nightly retain iOS comparators)"
  exit 0
fi
source Scripts/build-inputs.env
seen=()
for package in "$@"; do
  valid=false
  for known in "${TRINKET_TEST_PACKAGES[@]}"; do [[ "$package" != "$known" ]] || valid=true; done
  if [[ "$valid" != true || " ${seen[*]-} " == *" $package "* ]]; then
    echo "Unknown or duplicate package: $package" >&2; exit 2
  fi
  seen+=("$package")
done
native=()
ios=()
native_logic="${TRINKET_CI_NATIVE_LOGIC:-false}"
if [[ "${GITHUB_EVENT_NAME:-}" == push ]]; then native_logic=true; fi
qualified_native="${TRINKET_CI_NATIVE_PACKAGES-BattleEngine TrinketCore}"
for package in "$@"; do
  if [[ "$native_logic" == true && " $qualified_native " == *" $package "* ]]; then
    native+=("$package")
  else
    ios+=("$package")
  fi
done
if (( $# == 0 )); then echo "Expected package scope." >&2; exit 2; fi
# A pure-logic failure must not suppress the shard's save and app-state evidence.
# Keep the first failure while allowing each selected backend to finish.
status=0
if (( ${#native[@]} )); then
  ./Scripts/test-package-host.sh "${native[@]}" || status=$?
fi
# Purchase cancellation contracts have a deliberate one-minute limit. Run them
# separately from heavy MainActor save/career tests, retaining both disjoint sets.
regular_ios=()
state=false
if (( ${#ios[@]} )); then
  for package in "${ios[@]}"; do
    if [[ "$package" == TrinketAppState ]]; then state=true; else regular_ios+=("$package"); fi
  done
fi
if [[ "$state" == true ]]; then
  ios_status=0
  ./Scripts/test-package.sh --only-suite FullGameStoreTests TrinketAppState || ios_status=$?
  if (( status == 0 )); then status=$ios_status; fi
fi
if (( ${#regular_ios[@]} )); then
  ios_status=0
  ./Scripts/test-package.sh "${regular_ios[@]}" || ios_status=$?
  if (( status == 0 )); then status=$ios_status; fi
fi
if [[ "$state" == true ]]; then
  ios_status=0
  ./Scripts/test-package.sh --skip-suite FullGameStoreTests TrinketAppState || ios_status=$?
  if (( status == 0 )); then status=$ios_status; fi
fi
exit "$status"
