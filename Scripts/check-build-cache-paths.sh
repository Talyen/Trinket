#!/usr/bin/env bash
# Drift guard: required shared roots must appear in both local --no-build
# freshness (Scripts/build-inputs.sh) and CI DerivedData cache keys
# (.github/actions/build-cache-key/action.yml).
#
# Intentional differences (do not "fix" by forcing identical lists):
# - Cache uses Packages/** (broader); build-inputs enumerates TRINKET_TEST_PACKAGES
#   plus Packages/TrinketTestSupport.
# - Cache uses *.xctestplan; build-inputs lists each known plan by name.
# - changes.yml also watches .github/**, Trinket.xcodeproj/**, lint/format config —
#   those trigger CI jobs but are deliberately omitted from the cache key so
#   workflow-only edits can reuse warm DerivedData.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_INPUTS="$ROOT/Scripts/build-inputs.sh"
CACHE_KEY_ACTION="$ROOT/.github/actions/build-cache-key/action.yml"

die() {
  echo "check-build-cache-paths: $*" >&2
  exit 1
}

[[ -f "$BUILD_INPUTS" ]] || die "missing $BUILD_INPUTS"
[[ -f "$CACHE_KEY_ACTION" ]] || die "missing $CACHE_KEY_ACTION"

# Discrete quoted globs from hashFiles('a', 'b', ...) run steps only.
cache_glob_set=$'\n'
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    *'hashFiles('''*|*'hashFiles("'*)
      ;;
    *)
      continue
      ;;
  esac
  args="${line#*hashFiles(}"
  args="${args%%)*}"
  old_ifs=$IFS
  IFS=','
  # shellcheck disable=SC2086
  set -- $args
  IFS=$old_ifs
  for part in "$@"; do
    part="${part//\'/}"
    part="${part//\"/}"
    part="${part#"${part%%[![:space:]]*}"}"
    part="${part%"${part##*[![:space:]]}"}"
    [[ -n "$part" ]] || continue
    cache_glob_set+="${part}"$'\n'
  done
done <"$CACHE_KEY_ACTION"

[[ "$cache_glob_set" != $'\n' ]] || die "no hashFiles globs found in $CACHE_KEY_ACTION"

has_cache_glob() {
  [[ "$cache_glob_set" == *$'\n'"$1"$'\n'* ]]
}

missing=0

require_cache_glob() {
  local glob="$1"
  if ! has_cache_glob "$glob"; then
    echo "Missing discrete hashFiles glob in build-cache-key: $glob" >&2
    missing=1
  fi
}

require_cache_glob 'Trinket/**'
require_cache_glob 'TrinketUITests/**'
require_cache_glob 'ContentManifest/**'
require_cache_glob 'ArtManifest/**'
require_cache_glob 'MusicManifest/**'
require_cache_glob 'SoundManifest/**'
require_cache_glob 'CinematicManifest/**'
require_cache_glob 'Raw Assets/**'
require_cache_glob 'Scripts/**'
require_cache_glob 'project.yml'
require_cache_glob 'Packages/**'
require_cache_glob '*.xctestplan'

# Whole-line path tokens in build-inputs.sh arrays (quoted or bare).
require_build_inputs_line() {
  local token="$1"
  if grep -Eq "^[[:space:]]*${token}[[:space:]]*$" "$BUILD_INPUTS"; then
    return 0
  fi
  if grep -Eq "^[[:space:]]*\"${token}\"[[:space:]]*$" "$BUILD_INPUTS"; then
    return 0
  fi
  echo "Missing whole-line token in Scripts/build-inputs.sh: $token" >&2
  missing=1
}

require_build_inputs_line 'Trinket'
require_build_inputs_line 'TrinketUITests'
require_build_inputs_line 'ContentManifest'
require_build_inputs_line 'ArtManifest'
require_build_inputs_line 'MusicManifest'
require_build_inputs_line 'SoundManifest'
require_build_inputs_line 'CinematicManifest'
require_build_inputs_line 'Raw Assets'
require_build_inputs_line 'Scripts'
require_build_inputs_line 'project.yml'
require_build_inputs_line 'Packages/TrinketTestSupport'
require_build_inputs_line 'Smoke.xctestplan'
require_build_inputs_line 'QuickSmoke.xctestplan'
require_build_inputs_line 'FullUI.xctestplan'
require_build_inputs_line 'Integration.xctestplan'
require_build_inputs_line 'BattlePerformance.xctestplan'

# Package tenants come from TRINKET_TEST_PACKAGES; require the Packages/ prefix loop.
if ! grep -Fq 'Packages/$_trinket_test_package' "$BUILD_INPUTS" \
  && ! grep -Fq 'Packages/${_trinket_test_package}' "$BUILD_INPUTS"; then
  if ! grep -Fq 'build_input_paths+=("Packages/' "$BUILD_INPUTS"; then
    echo "Missing Packages/ tenant wiring in Scripts/build-inputs.sh" >&2
    missing=1
  fi
fi

# full hashFiles must include app + package sources (not only nonsource).
full_line="$(grep 'full=' "$CACHE_KEY_ACTION" | head -1 || true)"
[[ -n "$full_line" ]] || die "missing full= hashFiles line in build-cache-key"
# Quoted literals so ** is not treated as a glob in [[ ]].
if [[ "$full_line" != *'Trinket/**'* ]]; then
  echo "build-cache-key full hashFiles must include Trinket/**" >&2
  missing=1
fi
if [[ "$full_line" != *'Packages/**'* ]]; then
  echo "build-cache-key full hashFiles must include Packages/**" >&2
  missing=1
fi

if [[ "$missing" -ne 0 ]]; then
  die "path-list drift detected (see messages above)"
fi

echo "Build input / cache-key shared roots aligned."
