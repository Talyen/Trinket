#!/usr/bin/env bash
# Routine pushes use qualified native pure logic; qualification/nightly retain iOS.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == --help ]]; then
  echo "Usage: $0 <Package...> (CI native/iOS dispatcher; manual/nightly retain iOS comparators)"
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
for package in "$@"; do
  case "$package:${GITHUB_EVENT_NAME:-}" in
    BattleEngine:push|TrinketCore:push) native+=("$package") ;;
    *) ios+=("$package") ;;
  esac
done
if (( ${#native[@]} )); then ./Scripts/test-package-host.sh "${native[@]}"; fi
if (( ${#ios[@]} )); then ./Scripts/test-package.sh "${ios[@]}"; fi
if (( $# == 0 )); then echo "Expected package scope." >&2; exit 2; fi
