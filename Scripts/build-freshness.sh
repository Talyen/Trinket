#!/usr/bin/env bash
# Merged generated-input freshness + --no-build stamp helpers.
# Replaces Scripts/build-inputs.sh + Scripts/build-stamp.sh (deleted).
# Source this file from build/test entry points; it intentionally has no main.
# Function names and signatures are unchanged.

# shellcheck source=build-inputs.env
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build-inputs.env"

generation_paths_newer_than() {
  local stamp="$1"
  shift
  local paths=()
  local path

  for path in "$@"; do
    [[ -e "$path" ]] && paths+=("$path")
  done

  [[ ${#paths[@]} -gt 0 ]] || return 1
  find "${paths[@]}" -type f -newer "$stamp" 2>/dev/null
}

content_generation_inputs=("${TRINKET_CONTENT_GENERATION_INPUTS[@]}")
asset_generation_inputs=("${TRINKET_ASSET_GENERATION_INPUTS[@]}")
build_input_paths=("${TRINKET_BUILD_ROOTS[@]}" "${TRINKET_PROJECT_INPUTS[@]}")

generation_inputs_are_dirty() {
  local paths=("$@")
  local status
  status="$(git status --porcelain -- "${paths[@]}" 2>/dev/null)"
  status="$(printf '%s\n' "$status" | grep -v "\.md$" || true)"
  [[ -n "$status" ]]
}

generation_input_paths=(
  "${content_generation_inputs[@]}"
  project.yml
  "${asset_generation_inputs[@]}"
)

build_input_git_snapshot() {
  git status --porcelain -- "${build_input_paths[@]}" 2>/dev/null || true
}

record_build_input_git_snapshot() {
  local stamp="$1"
  printf '%s\n' "$(build_input_git_snapshot)" >"${stamp}.gitstatus"
}

generation_input_git_snapshot() {
  git status --porcelain -- "${generation_input_paths[@]}" 2>/dev/null || true
}

record_generate_input_git_snapshot() {
  local stamp="$1"
  printf '%s\n' "$(generation_input_git_snapshot)" >"${stamp}.gitstatus"
}

assert_generate_input_git_snapshot_unchanged() {
  local stamp="$1"
  local snapshot="${stamp}.gitstatus"
  local previous=""
  local current

  [[ -f "$snapshot" ]] || return 0

  previous="$(cat "$snapshot")"
  current="$(generation_input_git_snapshot)"
  [[ "$current" == "$previous" ]]
}

touch_generate_stamp() {
  local results_dir="${1:-${RESULTS_DIR:-$PWD/.DerivedData/TestResults}}"
  local stamp="$results_dir/.last-generate.stamp"
  mkdir -p "$results_dir"
  touch "$stamp"
  record_generate_input_git_snapshot "$stamp"
}

assert_build_input_git_snapshot_unchanged() {
  local stamp="$1"
  local fingerprint="$2"
  local snapshot="${stamp}.gitstatus"
  local previous=""
  local current

  [[ -f "$snapshot" ]] || return 0

  previous="$(cat "$snapshot")"
  current="$(build_input_git_snapshot)"
  if [[ "$current" != "$previous" ]]; then
    echo "--no-build refused because build-input git status changed after '$fingerprint':" >&2
    echo "  (working tree edits under build inputs since the last matching build)" >&2
    echo "Run without --no-build to rebuild app and test bundles." >&2
    return 1
  fi
}

prepare_generated_inputs() {
  local results_dir="$1"
  local stamp="$results_dir/.last-generate.stamp"
  local content_changed=""
  local project_changed=""
  local assets_changed=""
  local generate_args=()

  mkdir -p "$results_dir"
  if [[ "${SKIP_GENERATE:-0}" == "1" ]]; then
    echo "Generation skipped by SKIP_GENERATE=1."
    return 0
  fi

  if [[ -f "$stamp" ]]; then
    content_changed="$(generation_paths_newer_than "$stamp" "${content_generation_inputs[@]}")"
    project_changed="$(generation_paths_newer_than "$stamp" project.yml)"
    assets_changed="$(generation_paths_newer_than "$stamp" "${asset_generation_inputs[@]}")"
  fi
  if [[ -z "$content_changed" ]] && generation_inputs_are_dirty "${content_generation_inputs[@]}"; then
    content_changed="dirty content input"
  fi
  if [[ -z "$project_changed" ]] && generation_inputs_are_dirty project.yml; then
    project_changed="dirty project input"
  fi
  if [[ -z "$assets_changed" ]] && generation_inputs_are_dirty "${asset_generation_inputs[@]}"; then
    assets_changed="dirty asset input"
  fi

  if [[ -f "$stamp" && -z "$content_changed" && -z "$project_changed" && -z "$assets_changed" ]]; then
    echo "Generated inputs unchanged; skipping generate."
    return 0
  fi

  if [[ -n "$assets_changed" ]]; then
    echo "=== Asset inputs changed; running generate --assets ==="
    generate_args+=(--assets)
  elif [[ -n "$content_changed" && -z "$project_changed" ]]; then
    echo "=== Content inputs changed; running generate (skipping xcodegen) ==="
    generate_args+=(--skip-xcodegen)
  else
    echo "=== Running generate ==="
  fi

  if (( ${#generate_args[@]} )); then
    ./Scripts/generate.sh "${generate_args[@]}"
  else
    ./Scripts/generate.sh
  fi
  touch_generate_stamp "$results_dir"
}

assert_no_build_inputs_are_fresh() {
  local stamp="$1"
  local fingerprint="$2"
  local newer_files=()
  local file

  if [[ "${CI:-}" == "true" ]]; then
    echo "CI environment detected; cache key establishes --no-build freshness."
    return 0
  fi

  if [[ ! -f "$stamp" ]]; then
    echo "No prior built test stamp found for '$fingerprint'. Run without --no-build first." >&2
    return 1
  fi

  while IFS= read -r file; do
    newer_files+=("$file")
    [[ ${#newer_files[@]} -ge 10 ]] && break
  done < <(generation_paths_newer_than "$stamp" "${build_input_paths[@]}")

  if [[ ${#newer_files[@]} -gt 0 ]]; then
    echo "--no-build refused because build inputs changed after '$fingerprint':" >&2
    printf '  %s\n' "${newer_files[@]}" >&2
    echo "Run without --no-build to rebuild app and test bundles." >&2
    return 1
  fi

  assert_build_input_git_snapshot_unchanged "$stamp" "$fingerprint"
}

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
  record_build_input_git_snapshot "$stamp"
}

package_test_scheme() {
  case "$1" in
    BattleEngine) printf '%s\n' 'BattleEngine-Package' ;;
    TrinketContent) printf '%s\n' 'TrinketContent-Package' ;;
    TrinketFeatureSupport) printf '%s\n' 'TrinketFeatureSupport-Package' ;;
    TrinketPersistence) printf '%s\n' 'TrinketPersistence-Package' ;;
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

# shellcheck disable=SC2034
TRINKET_BUILD_FINGERPRINTS_APP=(
  smoke
  ui
)

# shellcheck disable=SC2034
TRINKET_BUILD_FINGERPRINTS_FULL=(
  unit
  "${TRINKET_BUILD_FINGERPRINTS_APP[@]}"
  all
)
