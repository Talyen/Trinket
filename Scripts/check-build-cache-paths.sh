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
# - Cache nonsource hashes Scripts/tool-versions.env, not Scripts/**, so
#   script-only CI edits prefix-restore; Scripts/** remains on the full key.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_INPUTS="$ROOT/Scripts/build-inputs.sh"
CACHE_KEY_ACTION="$ROOT/.github/actions/build-cache-key/action.yml"
# shellcheck source=build-inputs.sh
source "$BUILD_INPUTS"

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

for required_glob in "${TRINKET_CACHE_REQUIRED_ROOTS[@]}"; do
  require_cache_glob "$required_glob"
done

# Shared build-input ownership is loaded from build-inputs.sh above.
build_inputs_contain() {
  local token="$1"
  local input
  for input in "${build_input_paths[@]}"; do
    [[ "$input" == "$token" ]] && return 0
  done
  return 1
}

for required_input in "${TRINKET_BUILD_ROOTS[@]}" "${TRINKET_PROJECT_INPUTS[@]}"; do
  if ! build_inputs_contain "$required_input"; then
    echo "Missing shared build input: $required_input" >&2
    missing=1
  fi
done

# Package tenants come from TRINKET_TEST_PACKAGES; require the Packages/ prefix loop.
for package in "${TRINKET_TEST_PACKAGES[@]}"; do
  if ! build_inputs_contain "Packages/$package"; then
    echo "Missing package tenant in shared build inputs: Packages/$package" >&2
    missing=1
  fi
done

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

nonsource_line="$(grep 'nonsource=' "$CACHE_KEY_ACTION" | head -1 || true)"
[[ -n "$nonsource_line" ]] || die "missing nonsource= hashFiles line in build-cache-key"
if [[ "$nonsource_line" == *'Scripts/**'* ]]; then
  echo "nonsource hashFiles must not include Scripts/**; script-only edits should prefix-restore." >&2
  missing=1
fi
if [[ "$nonsource_line" != *'Scripts/tool-versions.env'* ]]; then
  echo "nonsource hashFiles must include Scripts/tool-versions.env" >&2
  missing=1
fi

if [[ "$missing" -ne 0 ]]; then
  die "path-list drift detected (see messages above)"
fi

echo "Build input / cache-key shared roots aligned."
