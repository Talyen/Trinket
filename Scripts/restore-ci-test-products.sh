#!/usr/bin/env bash
# Restore only compatible UI products; rebuild missing or incompatible transfers.
set -euo pipefail
cd "$(dirname "$0")/.."
source Scripts/build-freshness.sh

downloaded=false
if [[ "${1:-}" == --downloaded ]]; then downloaded=true; shift; fi
if [[ "${1:-}" != -- || $# -lt 2 ]]; then
  echo "Usage: $0 [--downloaded] -- <rebuild-command> [arguments...]" >&2
  exit 2
fi
shift

mkdir -p .DerivedData
# Destructive replacement is confined to this checkout's product directory.
if [[ "$(cd .DerivedData && pwd -P)" != "$(pwd -P)/.DerivedData" \
  || -L .DerivedData/Build || -L .DerivedData/TestResults ]]; then
  echo "Refusing to replace products through a symlinked build/results root." >&2
  exit 2
fi

discard_products() {
  rm -rf .DerivedData/Build/Products
  if [[ -d .DerivedData/TestResults ]]; then
    find .DerivedData/TestResults -maxdepth 1 -name '.last-build-*.stamp*' -type f -delete
  fi
}

validate_products() {
  [[ -d .DerivedData/Build/Products/Debug-iphonesimulator/Trinket.app ]] || return 1
  local test_runs=(.DerivedData/Build/Products/*.xctestrun)
  [[ -f "${test_runs[0]}" ]] || return 1
  local fingerprint
  for fingerprint in "${TRINKET_BUILD_FINGERPRINTS_APP[@]}"; do
    assert_no_build_inputs_are_fresh \
      "$(build_stamp_path .DerivedData/TestResults "$fingerprint")" "$fingerprint" || return $?
  done
}

discard_products
if [[ "$downloaded" == true ]] \
  && tar -xf .DerivedData/ci-test-artifact.tar -C .DerivedData \
  && validate_products; then
  echo "Reusing transferred test products: commit and build environment match."
  exit 0
fi

echo "Test products missing or incompatible; rebuilding on this runner."
discard_products
SKIP_GENERATE=1 "$@"
validate_products
