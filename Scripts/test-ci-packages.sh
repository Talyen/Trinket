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
for package in "$@"; do
  case "$package:$native_logic" in
    BattleEngine:true|TrinketCore:true) native+=("$package") ;;
    *) ios+=("$package") ;;
  esac
done
if (( $# == 0 )); then echo "Expected package scope." >&2; exit 2; fi
# A pure-logic failure must not suppress the shard's save and app-state evidence.
# Keep the first failure while allowing each selected backend to finish.
status=0
if (( ${#native[@]} )); then
  ./Scripts/test-package-host.sh "${native[@]}" || status=$?
fi
if (( ${#ios[@]} )); then
  ios_status=0
  ./Scripts/test-package.sh "${ios[@]}" || ios_status=$?
  if (( status == 0 )); then status=$ios_status; fi
fi
exit "$status"
