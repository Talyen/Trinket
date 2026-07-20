#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

REGENERATE=false
INCLUDE_ASSETS=false
# committed: fail when tracked generated paths differ from HEAD (CI / pre-push).
# idempotent: regenerate once and fail if tracked outputs still change (local verify-changed).
MODE="committed"

usage() {
  cat <<'EOF'
Usage: ./Scripts/assert-generated-output.sh [options]

Checks that generated catalogs/assets match their manifests.

Modes:
  (default)        Commit completeness — tracked generated paths must match HEAD.
                   Use after generate on a clean checkout (CI, pre-push, ci-gate).
  --idempotent     Consistency — run generate once more; tracked outputs must not
                   change again. Use after generate in verify-changed (local/agent).

Options:
  --regenerate     Run ./Scripts/generate.sh before the committed-mode check
  --assets         Include art/music/SFX/cinematic outputs when regenerating or checking
  --idempotent     Consistency check (see Modes); implies a regenerate pass
  -h, --help       Show this help

CI runs ./Scripts/generate.sh first, then this script without --regenerate.
verify-changed runs generate, then this script with --idempotent.
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
    --idempotent)
      MODE="idempotent"
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
  "Trinket.xcodeproj/project.pbxproj"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/ItemAffixCatalog.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalogBasic.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalogSkill.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalogUltimate.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityShorthand.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentChapters.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentRoster.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentHomestead.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentItemBases.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentTraits.generated.swift"
  "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEncounterArt.generated.swift"
)

if [[ "$INCLUDE_ASSETS" == true ]]; then
  TRACKED_PATHS+=(
    "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtSourceHashes.generated.tsv"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/MusicCatalog.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/SFXCatalog.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/UltimateCinematicCatalog.generated.swift"
    "Trinket/Assets.xcassets"
    "Trinket/Resources/Music"
    "Trinket/Resources/SFX"
    "Trinket/Resources/Cinematics"
  )
fi

run_generate() {
  if [[ "$INCLUDE_ASSETS" == true ]]; then
    ./Scripts/generate.sh --assets
  else
    ./Scripts/generate.sh
  fi
}

# Content fingerprint of tracked generated paths (files + trees). Stable across runs
# when generation is idempotent.
snapshot_tracked() {
  local path
  for path in "${TRACKED_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
      # shellcheck disable=SC2038
      find "$path" -type f ! -name '.DS_Store' -print \
        | LC_ALL=C sort \
        | while IFS= read -r file; do
            shasum -a 256 "$file"
          done
    elif [[ -f "$path" ]]; then
      shasum -a 256 "$path"
    else
      printf 'MISSING %s\n' "$path"
    fi
  done
}

print_tracked_diff_vs_head() {
  git diff -- "${TRACKED_PATHS[@]}" >&2 || true
  git diff --cached -- "${TRACKED_PATHS[@]}" >&2 || true
}

if [[ "$MODE" == "idempotent" ]]; then
  before="$(snapshot_tracked)"
  run_generate
  after="$(snapshot_tracked)"
  if [[ "$before" == "$after" ]]; then
    echo "Generated output is stable under regenerate (matches manifests)."
    exit 0
  fi
  echo "ERROR: Regenerating still changed tracked generated output." >&2
  echo "Generation is not idempotent, or another process mutated outputs mid-run." >&2
  if [[ "$INCLUDE_ASSETS" == true ]]; then
    echo "For art/music manifest edits, use ./Scripts/generate.sh --assets" >&2
  fi
  echo "" >&2
  # Show working-tree churn vs HEAD for triage (may include intentional uncommitted work).
  print_tracked_diff_vs_head
  exit 1
fi

if [[ "$REGENERATE" == true ]]; then
  run_generate
fi

if git diff --quiet -- "${TRACKED_PATHS[@]}" \
  && git diff --cached --quiet -- "${TRACKED_PATHS[@]}" 2>/dev/null; then
  echo "Generated output matches manifests (committed)."
  exit 0
fi

echo "ERROR: Generated output is stale or uncommitted." >&2
echo "If these are intentional task outputs, review them, commit or amend only the task scope, then rerun this gate." >&2
echo "Otherwise run ./Scripts/generate.sh and investigate the unexpected drift (including Trinket.xcodeproj when project.yml changed)." >&2
if [[ "$INCLUDE_ASSETS" == true ]]; then
  echo "For art/music manifest edits, use ./Scripts/generate.sh --assets" >&2
fi
echo "" >&2
print_tracked_diff_vs_head
exit 1
