#!/usr/bin/env bash
# Generated-output assert helpers. Executable as a gate; sourceable for the
# shared tracked-path list (agent-push-gate XcodeGen-unavailable fallback).

trinket_set_generated_tracked_paths() {
  local include_assets="${1:-false}"
  local include_pbxproj="${2:-true}"

  TRACKED_PATHS=()
  if [[ "$include_pbxproj" == true ]]; then
    TRACKED_PATHS+=(
      "Trinket.xcodeproj/project.pbxproj"
    )
  fi
  TRACKED_PATHS+=(
    "Packages/TrinketContent/Sources/TrinketContent/Generated/ItemAffixCatalog.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityShorthand.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityInventory.generated.tsv"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalogIndex.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentStagesIndex.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentChapters.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentRoster.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentHomestead.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentItemBases.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentTraits.generated.swift"
    "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEncounterArt.generated.swift"
  )

  if [[ "$include_assets" == true ]]; then
    TRACKED_PATHS+=(
      "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift"
      "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtSourceHashes.generated.tsv"
      "Packages/TrinketContent/Sources/TrinketContent/Generated/MusicCatalog.generated.swift"
      "Packages/TrinketContent/Sources/TrinketContent/Generated/MusicSourceHashes.generated.tsv"
      "Packages/TrinketContent/Sources/TrinketContent/Generated/SFXCatalog.generated.swift"
      "Packages/TrinketContent/Sources/TrinketContent/Generated/SFXSourceHashes.generated.tsv"
      "Packages/TrinketContent/Sources/TrinketContent/Generated/UltimateCinematicCatalog.generated.swift"
      "Packages/TrinketContent/Sources/TrinketContent/Generated/UltimateCinematicSourceHashes.generated.tsv"
      "Packages/TrinketContent/Sources/TrinketContent/Generated/AppIconSourceHashes.generated.tsv"
      "Trinket/Assets.xcassets"
      "Trinket/Resources/Music"
      "Trinket/Resources/SFX"
      "Trinket/Resources/Cinematics"
    )
  fi
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0 2>/dev/null || true
fi

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

trinket_set_generated_tracked_paths "$INCLUDE_ASSETS" true

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
      find "$path" -type f ! -name '.DS_Store' -print0 \
        | LC_ALL=C sort -z \
        | xargs -0 shasum -a 256 2>/dev/null
    elif [[ -f "$path" ]]; then
      shasum -a 256 "$path"
    else
      printf 'MISSING %s\n' "$path"
    fi
  done
}

print_tracked_diff_vs_head() {
  echo "--- Diff summary ---" >&2
  git status --porcelain=v1 --untracked-files=all -- "${TRACKED_PATHS[@]}" >&2 || true
  git diff --stat -- "${TRACKED_PATHS[@]}" >&2 || true
  git diff --cached --stat -- "${TRACKED_PATHS[@]}" >&2 || true
  echo "--- First 100 lines of diff ---" >&2
  git diff -- "${TRACKED_PATHS[@]}" | head -n 100 >&2 || true
  git diff --cached -- "${TRACKED_PATHS[@]}" | head -n 100 >&2 || true
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

tracked_status="$(git status --porcelain=v1 --untracked-files=all -- "${TRACKED_PATHS[@]}")"
if [[ -z "$tracked_status" ]]; then
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
