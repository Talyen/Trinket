#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

REGENERATE=false
INCLUDE_ASSETS=false

usage() {
  cat <<'EOF'
Usage: ./Scripts/assert-generated-output.sh [options]

Fails when committed generated output does not match manifests.

Options:
  --regenerate     Run ./Scripts/generate.sh before checking (default: check only)
  --assets         Include art/music outputs when regenerating or checking
  -h, --help       Show this help

CI runs ./Scripts/generate.sh first, then this script without --regenerate.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --regenerate)
      REGENERATE=true
      shift
      ;;
    --assets)
      INCLUDE_ASSETS=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

TRACKED_PATHS=(
  "Packages/TrinketContent/Sources/TrinketContent/Generated/ItemAffixCatalog.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalogBasic.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalogSkill.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalogUltimate.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityShorthand.generated.swift"
)

if [[ "$INCLUDE_ASSETS" == true ]]; then
  TRACKED_PATHS+=(
    "Trinket/Generated/ArtCatalog.generated.swift"
    "Trinket/Generated/MusicCatalog.generated.swift"
    "Trinket/Assets.xcassets"
    "Trinket/Resources/Music"
  )
fi

if [[ "$REGENERATE" == true ]]; then
  GENERATE_ARGS=()
  if [[ "$INCLUDE_ASSETS" == true ]]; then
    GENERATE_ARGS+=(--assets)
  fi
  ./Scripts/generate.sh "${GENERATE_ARGS[@]}"
fi

if git diff --quiet -- "${TRACKED_PATHS[@]}" \
  && git diff --cached --quiet -- "${TRACKED_PATHS[@]}" 2>/dev/null; then
  echo "Generated output matches manifests."
  exit 0
fi

echo "ERROR: Generated output is stale or uncommitted." >&2
echo "Run ./Scripts/generate.sh and commit the updated files." >&2
if [[ "$INCLUDE_ASSETS" == true ]]; then
  echo "For art/music manifest edits, use ./Scripts/generate.sh --assets" >&2
fi
echo "" >&2
git diff -- "${TRACKED_PATHS[@]}" >&2 || true
git diff --cached -- "${TRACKED_PATHS[@]}" >&2 || true
exit 1
