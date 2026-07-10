#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -gt 0 ]]; then
  case "$1" in
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/changed-source-summary.sh

Lists authored working-tree changes, omits generated/processed output detail, and
prints the focused context cards and likely verification commands.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
fi

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
  echo "No working-tree changes."
  exit 0
fi

has_content=false
has_assets=false
has_project=false
has_swift=false
has_app_state=false
has_feature=false
has_audio=false
has_docs_or_tools=false
declare -a authored=()
declare -a omitted=()
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
    Packages/*/Generated/*|Trinket/Assets.xcassets/*|Trinket/Resources/Music/*|Trinket/Resources/SFX/*|Trinket/Resources/Cinematics/*)
      omitted+=("$path")
      ;;
    ContentManifest/*|Packages/TrinketContent/Sources/TrinketContent/Content/*)
      has_content=true
      authored+=("$path")
      ;;
    ArtManifest/*|MusicManifest/*|SoundManifest/*|CinematicManifest/*|Raw\ Assets/*)
      has_assets=true
      authored+=("$path")
      ;;
    project.yml)
      has_project=true
      authored+=("$path")
      ;;
    Packages/BattleEngine/*.swift|Packages/BattleEngine/**/*.swift)
      has_swift=true
      add_package BattleEngine
      authored+=("$path")
      ;;
    Packages/TrinketContent/*.swift|Packages/TrinketContent/**/*.swift)
      has_swift=true
      add_package TrinketContent
      authored+=("$path")
      ;;
    Packages/TrinketPersistence/*.swift|Packages/TrinketPersistence/**/*.swift)
      has_swift=true
      add_package TrinketPersistence
      authored+=("$path")
      ;;
    Packages/TrinketCore/*.swift|Packages/TrinketCore/**/*.swift)
      has_swift=true
      add_package TrinketCore
      authored+=("$path")
      ;;
    Packages/TrinketDesignSystem/*.swift|Packages/TrinketDesignSystem/**/*.swift)
      has_swift=true
      add_package TrinketDesignSystem
      authored+=("$path")
      ;;
    Trinket/State/*|Trinket/App/*|Trinket/BattleShell/*)
      has_swift=true
      has_app_state=true
      authored+=("$path")
      ;;
    Trinket/Features/*|Trinket/Shared/*|Trinket/Models/*|TrinketUITests/*)
      has_swift=true
      has_feature=true
      authored+=("$path")
      ;;
    Trinket/Audio/*)
      has_swift=true
      has_audio=true
      authored+=("$path")
      ;;
    *.swift)
      has_swift=true
      authored+=("$path")
      ;;
    Docs/*|*.md|Scripts/*|.github/*)
      has_docs_or_tools=true
      authored+=("$path")
      ;;
    *)
      authored+=("$path")
      ;;
  esac
done

echo "Authored changes (${#authored[@]}):"
printf '  %s\n' "${authored[@]}"
if [[ ${#omitted[@]} -gt 0 ]]; then
  echo "Generated or processed outputs omitted (${#omitted[@]})."
fi

echo ""
echo "Context cards:"
if [[ "$has_content" == true || "$has_assets" == true ]]; then echo "  Docs/AgentContext/content-and-manifests.md"; fi
if [[ " ${packages[*]} " == *" BattleEngine "* ]]; then echo "  Docs/AgentContext/battle.md"; fi
if [[ " ${packages[*]} " == *" TrinketPersistence "* ]]; then echo "  Docs/AgentContext/persistence.md"; fi
if [[ "$has_feature" == true ]]; then echo "  Docs/AgentContext/swiftui-features.md"; fi
if [[ "$has_audio" == true ]]; then echo "  Docs/AgentContext/audio.md"; fi
if [[ "$has_project" == true || "$has_docs_or_tools" == true ]]; then echo "  Docs/AgentContext/ci-and-project-generation.md"; fi

echo ""
echo "Suggested verification (preview with ./Scripts/verify-changed.sh --dry-run):"
if [[ "$has_content" == true ]]; then echo "  ./Scripts/generate.sh"; fi
if [[ "$has_assets" == true ]]; then echo "  ./Scripts/generate.sh --assets"; fi
if [[ "$has_project" == true ]]; then echo "  ./Scripts/generate.sh"; fi
if [[ "$has_swift" == true ]]; then echo "  ./Scripts/test.sh style"; fi
for package in "${packages[@]}"; do echo "  ./Scripts/test-package.sh $package"; done
if [[ "$has_app_state" == true || "$has_audio" == true ]]; then echo "  ./Scripts/test.sh unit"; fi
if [[ "$has_feature" == true ]]; then echo "  ./Scripts/test.sh smoke"; fi
