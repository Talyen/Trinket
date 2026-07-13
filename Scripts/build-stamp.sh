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
}

package_test_scheme() {
  case "$1" in
    BattleEngine) printf '%s\n' 'BattleEngine-Package' ;;
    *) printf '%s\n' "$1" ;;
  esac
}
