#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/verify-changed.sh [--dry-run]

Classifies working-tree source changes, runs any required generation once, then
runs the smallest focused verification commands sequentially. It deliberately
does not run pre-push or pre-merge gates.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

declare -a changed=()
while IFS= read -r path; do
  [[ -n "$path" ]] && changed+=("$path")
done < <(
  {
    git diff --name-only --diff-filter=ACMRD HEAD
    git ls-files --others --exclude-standard
  } | sort -u
)

if [[ ${#changed[@]} -eq 0 ]]; then
  echo "No working-tree changes to verify."
  exit 0
fi

needs_content_generation=false
needs_asset_generation=false
needs_project_generation=false
needs_style=false
needs_unit=false
needs_smoke=false
declare -a packages=()

add_package() {
  local candidate="$1"
  local package
  for package in "${packages[@]:-}"; do
    [[ "$package" == "$candidate" ]] && return
  done
  packages+=("$candidate")
}

for path in "${changed[@]}"; do
  case "$path" in
    ContentManifest/*|Packages/TrinketContent/Sources/TrinketContent/Content/*)
      needs_content_generation=true
      ;;
    ArtManifest/*|MusicManifest/*|SoundManifest/*|CinematicManifest/*|Raw\ Assets/*)
      needs_asset_generation=true
      ;;
    project.yml)
      needs_project_generation=true
      ;;
    Packages/BattleEngine/*.swift|Packages/BattleEngine/**/*.swift)
      needs_style=true
      add_package BattleEngine
      ;;
    Packages/TrinketContent/*.swift|Packages/TrinketContent/**/*.swift)
      needs_style=true
      add_package TrinketContent
      ;;
    Packages/TrinketPersistence/*.swift|Packages/TrinketPersistence/**/*.swift)
      needs_style=true
      add_package TrinketPersistence
      ;;
    Packages/TrinketCore/*.swift|Packages/TrinketCore/**/*.swift)
      needs_style=true
      add_package TrinketCore
      ;;
    Packages/TrinketDesignSystem/*.swift|Packages/TrinketDesignSystem/**/*.swift)
      needs_style=true
      add_package TrinketDesignSystem
      ;;
    Trinket/State/*|Trinket/App/*|Trinket/BattleShell/*|TrinketTests/*|Trinket/Audio/*)
      needs_style=true
      needs_unit=true
      ;;
    Trinket/Features/*|Trinket/Shared/*|Trinket/Models/*|TrinketUITests/*)
      needs_style=true
      needs_smoke=true
      ;;
  esac
done

if [[ "$needs_asset_generation" == true ]]; then
  needs_content_generation=true
fi
if [[ "$needs_project_generation" == true ]]; then
  needs_content_generation=true
fi

declare -a commands=()
if [[ "$needs_asset_generation" == true ]]; then
  commands+=("./Scripts/generate.sh --assets")
elif [[ "$needs_content_generation" == true || "$needs_project_generation" == true ]]; then
  commands+=("./Scripts/generate.sh")
fi
if [[ "$needs_content_generation" == true || "$needs_asset_generation" == true || "$needs_project_generation" == true ]]; then
  assert_args=""
  [[ "$needs_asset_generation" == true ]] && assert_args=" --assets"
  commands+=("./Scripts/assert-generated-output.sh${assert_args}")
fi
if [[ "$needs_style" == true ]]; then commands+=("./Scripts/test.sh style"); fi
for package in "${packages[@]}"; do commands+=("./Scripts/test-package.sh $package"); done
if [[ "$needs_unit" == true ]]; then commands+=("SKIP_GENERATE=1 ./Scripts/test.sh unit"); fi
if [[ "$needs_smoke" == true ]]; then commands+=("SKIP_GENERATE=1 ./Scripts/test.sh smoke"); fi

if [[ ${#commands[@]} -eq 0 ]]; then
  echo "No source verification selected for the current changes."
  echo "Review docs/tooling changes directly; use ci-gate or a task-specific command when appropriate."
  exit 0
fi

echo "Verification plan (sequential):"
printf '  %s\n' "${commands[@]}"
if [[ "$DRY_RUN" == true ]]; then
  exit 0
fi

for command in "${commands[@]}"; do
  echo ""
  echo "=== $command ==="
  eval "$command"
done
