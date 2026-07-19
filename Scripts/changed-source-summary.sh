#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Keep source routing aligned with verify-changed.sh and agent-context.sh.
# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh

PATH_MODE="working-tree"
declare -a requested_paths=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/changed-source-summary.sh [--paths <file> ...]

Lists task-scoped changes (when --paths is supplied) or working-tree changes,
omits generated/processed output detail, and prints focused context cards and
likely verification commands. Paths are repository-relative; --paths consumes
all remaining arguments.
USAGE
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
      exit 1
      ;;
  esac
  shift
done

trinket_collect_paths "$PATH_MODE" "${requested_paths[@]-}"

if [[ ${#TRINKET_CHANGED_PATHS[@]} -eq 0 ]]; then
  echo "No working-tree changes."
  exit 0
fi

trinket_classify_paths
trinket_build_verification_plan
authored=()
omitted=()
packages=()
if (( ${#TRINKET_AUTHORED_PATHS[@]} > 0 )); then authored=("${TRINKET_AUTHORED_PATHS[@]}"); fi
if (( ${#TRINKET_GENERATED_PATHS[@]} > 0 )); then omitted=("${TRINKET_GENERATED_PATHS[@]}"); fi
if (( ${#TRINKET_PACKAGES[@]} > 0 )); then packages=("${TRINKET_PACKAGES[@]}"); fi
has_content="$TRINKET_HAS_CONTENT"
has_assets="$TRINKET_HAS_ASSETS"
has_project="$TRINKET_HAS_PROJECT"
has_feature="$TRINKET_HAS_FEATURE"
has_audio="$TRINKET_HAS_AUDIO"
has_docs_or_tools="$TRINKET_HAS_DOCS_OR_TOOLS"

if [[ "$PATH_MODE" == "explicit" ]]; then
  echo "Task-scoped authored changes (${#authored[@]}):"
else
  echo "Working-tree authored changes (${#authored[@]}):"
fi
if (( ${#authored[@]} > 0 )); then
  printf '  %s\n' "${authored[@]}"
fi
if [[ ${#omitted[@]} -gt 0 ]]; then
  echo "Generated or processed outputs omitted (${#omitted[@]})."
fi

echo ""
echo "Context cards:"
if [[ "$has_content" == true || "$has_assets" == true ]]; then echo "  Docs/AgentContext/content-and-manifests.md"; fi
if [[ " ${packages[*]-} " == *" BattleEngine "* ]]; then echo "  Docs/AgentContext/battle.md"; fi
if [[ " ${packages[*]-} " == *" TrinketPersistence "* ]]; then echo "  Docs/AgentContext/persistence.md"; fi
if [[ "$has_feature" == true ]]; then echo "  Docs/AgentContext/swiftui-features.md"; fi
if [[ "$has_audio" == true ]]; then echo "  Docs/AgentContext/audio.md"; fi
if [[ "$has_project" == true || "$has_docs_or_tools" == true ]]; then echo "  Docs/AgentContext/ci-and-project-generation.md"; fi

echo ""
if [[ "$PATH_MODE" == "explicit" ]]; then
  echo "Suggested verification (preview with ./Scripts/verify-changed.sh --dry-run --paths <same files>)"
else
  echo "Suggested verification (preview with ./Scripts/verify-changed.sh --dry-run)"
fi
if (( ${#TRINKET_VERIFICATION_COMMANDS[@]} > 0 )); then
  printf '  %s\n' "${TRINKET_VERIFICATION_COMMANDS[@]}"
else
  echo "  (none; review docs/tooling directly)"
fi
if [[ "$TRINKET_SMOKE_TARGET_UNRESOLVED" == true ]]; then
  echo "  UI note: apply the Testing rubric; add coverage only for a qualifying unique shipping outcome. Do not substitute bare smoke."
fi
