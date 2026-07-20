#!/usr/bin/env bash
# Commit-completeness gate for agents after commit and before push.
# Regenerates with pinned XcodeGen (forced), then asserts generated output vs HEAD.
# Conditionally includes asset pipelines when classification says assets changed.
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh

PATH_MODE="working-tree"
declare -a requested_paths=()

usage() {
  cat <<'EOF'
Usage: ./Scripts/agent-push-gate.sh [--paths <file> ...]

Ensures generated catalogs/assets/project.pbxproj match what CI will regenerate:
  1. ./Scripts/ensure-ci-tools.sh (pinned SwiftFormat/SwiftLint/XcodeGen)
  2. ./Scripts/generate.sh [--assets] --force-xcodegen
  3. ./Scripts/assert-generated-output.sh [--assets]

Without --paths, classifies the whole working tree. With --paths, only those
paths drive whether --assets is included.

Agents: run this after committing the reviewed task scope and before pushing.
Pre-push also calls this script.

Env:
  SKIP_TRINKET_PUSH_GATE=1   Skip (for emergencies only)
  FORCE_ASSET_REENCODE=1     Force binary re-encode during generate --assets
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help | -h)
      usage
      exit 0
      ;;
    --paths)
      PATH_MODE="explicit"
      shift
      if [[ $# -eq 0 ]]; then
        echo "--paths requires at least one repository-relative path" >&2
        exit 1
      fi
      requested_paths=("$@")
      break
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "${SKIP_TRINKET_PUSH_GATE:-}" == "1" ]]; then
  echo "Skipping agent push gate (SKIP_TRINKET_PUSH_GATE=1)."
  exit 0
fi

echo "=== Agent push gate: pinned tools ==="
./Scripts/ensure-ci-tools.sh
export PATH="$PWD/.tools:$PATH"
export TRINKET_REQUIRE_PINNED_TOOLS=1

trinket_collect_paths "$PATH_MODE" "${requested_paths[@]-}"

report_change_budget() {
  if [[ "$PATH_MODE" == "explicit" ]]; then
    ./Scripts/change-budget.sh --paths "${TRINKET_CHANGED_PATHS[@]}"
  else
    ./Scripts/change-budget.sh
  fi
}

if [[ ${#TRINKET_CHANGED_PATHS[@]} -eq 0 && "$PATH_MODE" == "working-tree" ]]; then
  # Clean tree still re-generate + assert so committed outputs match pinned tools.
  echo "Working tree clean; regenerating to assert commit completeness."
fi
if [[ ${#TRINKET_CHANGED_PATHS[@]} -gt 0 ]]; then
  trinket_classify_paths
else
  trinket_reset_classification
fi

INCLUDE_ASSETS=false
if [[ "$TRINKET_NEEDS_ASSET_GENERATION" == true ]]; then
  INCLUDE_ASSETS=true
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "=== Agent push gate: generate (XcodeGen unavailable; content only) ==="
  ./Scripts/generate.sh --skip-xcodegen
  echo "=== Agent push gate: assert content catalogs ==="
  TRACKED=(
    Packages/TrinketContent/Sources/TrinketContent/Generated/ItemAffixCatalog.generated.swift
    Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalogBasic.generated.swift
    Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalogSkill.generated.swift
    Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalogUltimate.generated.swift
    Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityShorthand.generated.swift
    Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentChapters.generated.swift
    Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentRoster.generated.swift
    Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift
    Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentHomestead.generated.swift
    Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentItemBases.generated.swift
    Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentTraits.generated.swift
    Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEncounterArt.generated.swift
  )
  if ! git diff --quiet -- "${TRACKED[@]}"; then
    echo "ERROR: Generated content catalogs drifted. Commit the Generated/*.swift updates." >&2
    git diff -- "${TRACKED[@]}" >&2 || true
    exit 1
  fi
  echo "Content catalogs match manifests (pbxproj assert deferred to CI/XcodeGen)."
  report_change_budget
  echo "=== Agent push gate passed ==="
  echo "Note: push-gate is generate/assert completeness only — not style or compile."
  echo "Pre-CI source checks: ./Scripts/verify-changed.sh --isolate --paths …"
  echo "Tip: after push, run ./Scripts/agent-watch-ci.sh"
  exit 0
fi

echo "=== Agent push gate: generate (pinned XcodeGen, force rewrite) ==="
if [[ "$INCLUDE_ASSETS" == true ]]; then
  ./Scripts/generate.sh --assets --force-xcodegen
  echo "=== Agent push gate: assert generated output (including assets) ==="
  ./Scripts/assert-generated-output.sh --assets
else
  ./Scripts/generate.sh --force-xcodegen
  echo "=== Agent push gate: assert generated output ==="
  ./Scripts/assert-generated-output.sh
fi

report_change_budget
echo "=== Agent push gate passed ==="
echo "Note: push-gate is generate/assert completeness only — not style or compile."
echo "Pre-CI source checks: ./Scripts/verify-changed.sh --isolate --paths …"
echo "Tip: after push, run ./Scripts/agent-watch-ci.sh"
