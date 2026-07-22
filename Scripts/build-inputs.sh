#!/usr/bin/env bash
# Shared generated-input and --no-build freshness helpers.
# Source this file from build/test entry points; it intentionally has no main.

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

content_generation_inputs=(
  ContentManifest
  Scripts/content_codegen.py
)

asset_generation_inputs=(
  ArtManifest
  MusicManifest
  SoundManifest
  CinematicManifest
  "Raw Assets"
  Scripts/prepare-app-icon.sh
  Scripts/prepare-art-assets.sh
  Scripts/prepare-cinematic-assets.sh
  Scripts/prepare-music-assets.sh
  Scripts/prepare-sfx-assets.sh
)

build_input_paths=(
  Trinket
  TrinketTests
  TrinketUITests
  Packages/TrinketCore
  Packages/TrinketContent
  Packages/BattleEngine
  Packages/TrinketPersistence
  Packages/TrinketDesignSystem
  Packages/TrinketTestSupport
  ContentManifest
  ArtManifest
  MusicManifest
  SoundManifest
  CinematicManifest
  "Raw Assets"
  Scripts
  project.yml
  Package.resolved
)

generation_inputs_are_dirty() {
  local paths=("$@")
  [[ -n "$(git status --porcelain -- "${paths[@]}")" ]]
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
  # Edits can preserve stale mtimes (e.g. Darkroom exports or generated
  # manifest rewrites). Git dirtiness catches those even when find -newer would
  # miss them, including content and project inputs.
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
  touch "$stamp"
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
}
