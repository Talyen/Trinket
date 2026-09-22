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
project_generation_inputs=("${TRINKET_PROJECT_GENERATION_INPUTS[@]}" Trinket.xcodeproj/project.pbxproj)
build_input_paths=("${TRINKET_BUILD_ROOTS[@]}" "${TRINKET_PROJECT_INPUTS[@]}")

generation_input_snapshot() {
  generation_input_snapshots "$@"
}

# Hash generation-input groups in one interpreter invocation, printing one
# hex digest per group in argument order. Groups are separated by `--`
# (patterns keep spaces, e.g. "Raw Assets", as single arguments). Without a
# `--` separator this behaves exactly like generation_input_snapshot.
generation_input_snapshots() {
  python3 - "$@" <<'PY_SNAPSHOT'
import glob
import hashlib
import json
import sys
from pathlib import Path

groups = [[]]
for pattern in sys.argv[1:]:
    if pattern == "--":
        groups.append([])
    else:
        groups[-1].append(pattern)

for patterns in groups:
    records = {}
    for pattern in patterns:
        matches = glob.glob(pattern)
        records[pattern] = None
        for match in matches:
            path = Path(match)
            files = path.rglob("*") if path.is_dir() else [path]
            for file in files:
                if file.is_file() and file.suffix != ".md":
                    stat = file.stat()
                    records[str(file)] = [stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns]
    print(hashlib.sha256(json.dumps(records, sort_keys=True).encode()).hexdigest())
PY_SNAPSHOT
}

build_input_git_snapshot() {
  git status --porcelain -- "${build_input_paths[@]}" 2>/dev/null || true
}

record_build_input_git_snapshot() {
  local stamp="$1"
  printf '%s\n' "$(build_input_git_snapshot)" >"${stamp}.gitstatus"
}

touch_generate_stamp() {
  local results_dir="${1:-${RESULTS_DIR:-$PWD/.DerivedData/TestResults}}"
  local stamp="$results_dir/.last-generate.stamp"
  local content_digest project_digest assets_digest
  mkdir -p "$results_dir"
  # One interpreter invocation per stamp; digests print in group order.
  {
    read -r content_digest
    read -r project_digest
    read -r assets_digest
  } < <(generation_input_snapshots "${content_generation_inputs[@]}" -- "${project_generation_inputs[@]}" -- "${asset_generation_inputs[@]}") || return $?
  printf '%s\n' "$content_digest" > "$stamp.content" || return $?
  printf '%s\n' "$project_digest" > "$stamp.project" || return $?
  printf '%s\n' "$assets_digest" > "$stamp.assets" || return $?
  touch "$stamp"
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

  local content_snapshot project_snapshot assets_snapshot
  {
    read -r content_snapshot
    read -r project_snapshot
    read -r assets_snapshot
  } < <(generation_input_snapshots "${content_generation_inputs[@]}" -- "${project_generation_inputs[@]}" -- "${asset_generation_inputs[@]}") || return $?
  [[ -f "$stamp.content" && "$(cat "$stamp.content")" == "$content_snapshot" ]] || content_changed=changed
  [[ -f "$stamp.project" && "$(cat "$stamp.project")" == "$project_snapshot" ]] || project_changed=changed
  if [[ -f "$stamp.assets" ]]; then
    [[ "$(cat "$stamp.assets")" == "$assets_snapshot" ]] || assets_changed=changed
  else
    # A legacy or absent stamp gets normal generation; asset conversion remains
    # selected by changed inputs or dirty asset sources on the first preparation.
    assets_changed="$(generation_paths_newer_than "$stamp" "${asset_generation_inputs[@]}" 2>/dev/null || true)"
    if [[ -z "$assets_changed" ]]; then
      assets_changed="$(git status --porcelain -- "${asset_generation_inputs[@]}" 2>/dev/null | grep -v '\.md$' || true)"
    fi
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
    ./Scripts/generate.sh "${generate_args[@]}" || return $?
  else
    ./Scripts/generate.sh || return $?
  fi
  touch_generate_stamp "$results_dir"
}

assert_no_build_inputs_are_fresh() {
  local stamp="$1"
  local fingerprint="$2"
  local newer_files=()
  local file

  if [[ ! -f "$stamp" ]]; then
    echo "No prior built test stamp found for '$fingerprint'. Run without --no-build first." >&2
    return 1
  fi

  python3 Scripts/build-metadata.py check "$(dirname "$stamp")" "$fingerprint" || return $?
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    # CI checkouts have fresh mtimes; the transferred metadata proves commit
    # and toolchain identity instead of relying on checkout timestamps.
    return 0
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
  python3 Scripts/build-metadata.py write "$results_dir" "$fingerprint" \
    --started "${TRINKET_BUILD_STARTED_IDENTITY:-}" || return $?
  record_build_input_git_snapshot "$stamp" || return $?
  touch "$stamp"
}

# Invalidate the product family's old stamps before Xcode can partially replace
# binaries. The identity is kept in the caller, including per-package workers.
begin_build_stamps() {
  TRINKET_BUILD_STARTED_IDENTITY="$(python3 Scripts/build-metadata.py begin "$1" "$2")" || return $?
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

# Shared per-package scheme invocation prefix: scheme, SDK, destination, the
# per-package DerivedData tenant pins that keep parallel package builds off
# the shared Packages/.DerivedData/build.db, parallel target builds, and
# hermetic package resolution pinned to the resolution lockfile (no network).
# Callers run this then append their action word plus action-specific flags,
# so the build-for-testing and test branches cannot drift on tenant layout
# or build behavior.
# Usage: trinket_set_package_scheme_args "$scheme" "$sdk" "$destination" "$package_dd"
#        xcodebuild_args=(xcodebuild <action> "${TRINKET_PACKAGE_SCHEME_ARGS[@]}" ...)
trinket_set_package_scheme_args() {
  local scheme="$1" sdk="$2" destination="$3" package_dd="$4"
  TRINKET_PACKAGE_SCHEME_ARGS=(
    -scheme "$scheme"
    -sdk "$sdk"
    -destination "$destination"
    -derivedDataPath "$package_dd"
    -parallelizeTargets
    -disableAutomaticPackageResolution
    "SYMROOT=$(package_symroot "$package_dd")"
    "OBJROOT=$(package_objroot "$package_dd")"
    "SHARED_PRECOMPS_DIR=$(package_shared_precomps_dir "$package_dd")"
  )
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
