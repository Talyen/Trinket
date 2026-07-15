#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh

OUTPUT="agent"
PATH_MODE="working-tree"
declare -a requested_paths=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) OUTPUT="json" ;;
    --agent) OUTPUT="agent" ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/agent-context.sh [--agent|--json] [--paths <file> ...]

Prints a compact task briefing: applicable AGENTS.md guides, context cards and
skills, architecture/generated-output warnings, and the focused sequential
verification plan. Agents should run the recommended verify-changed --isolate
command. Paths are repository-relative; --paths consumes all remaining
arguments. Without --paths, the working tree is classified.
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
trinket_classify_paths
trinket_build_verification_plan

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '"%s"' "$value"
}

json_array() {
  local array_name="$1"
  local item
  local first=true
  local count
  printf '['
  eval "count=\${#$array_name[@]}"
  if (( count > 0 )); then
    eval "for item in \"\${${array_name}[@]}\"; do
      if [[ \"\$first\" == true ]]; then first=false; else printf ','; fi
      json_escape \"\$item\"
    done"
  fi
  printf ']'
}

json_bool() {
  if [[ "$1" == true ]]; then printf true; else printf false; fi
}

print_json() {
  printf '{'
  printf '"version":1,'
  printf '"path_mode":'; json_escape "$PATH_MODE"; printf ','
  printf '"paths":'; json_array TRINKET_CHANGED_PATHS; printf ','
  printf '"authored_paths":'; json_array TRINKET_AUTHORED_PATHS; printf ','
  printf '"generated_paths":'; json_array TRINKET_GENERATED_PATHS; printf ','
  printf '"agent_guides":{"root":"AGENTS.md","nested":'; json_array TRINKET_AGENT_GUIDES; printf '},'
  printf '"context_cards":'; json_array TRINKET_CONTEXT_CARDS; printf ','
  printf '"skills":'; json_array TRINKET_SKILLS; printf ','
  printf '"boundary_warnings":'; json_array TRINKET_BOUNDARY_WARNINGS; printf ','
  printf '"generated_warnings":'; json_array TRINKET_GENERATED_WARNINGS; printf ','
  printf '"verification_commands":'; json_array TRINKET_VERIFICATION_COMMANDS; printf ','
  printf '"smoke_targets":'; json_array TRINKET_SMOKE_TARGETS; printf ','
  printf '"flags":{'
  printf '"content":'; json_bool "$TRINKET_HAS_CONTENT"; printf ','
  printf '"assets":'; json_bool "$TRINKET_HAS_ASSETS"; printf ','
  printf '"project":'; json_bool "$TRINKET_HAS_PROJECT"; printf ','
  printf '"swift":'; json_bool "$TRINKET_HAS_SWIFT"; printf ','
  printf '"app_state":'; json_bool "$TRINKET_HAS_APP_STATE"; printf ','
  printf '"feature":'; json_bool "$TRINKET_HAS_FEATURE"; printf ','
  printf '"audio":'; json_bool "$TRINKET_HAS_AUDIO"; printf ','
  printf '"docs_or_tools":'; json_bool "$TRINKET_HAS_DOCS_OR_TOOLS"; printf ','
  printf '"smoke_target_unresolved":'; json_bool "$TRINKET_SMOKE_TARGET_UNRESOLVED"
  printf '}'
  printf '}'
  printf '\n'
}

print_agent() {
  if [[ "$PATH_MODE" == explicit ]]; then
    printf 'Agent context (explicit paths, %d):\n' "${#TRINKET_CHANGED_PATHS[@]}"
  else
    printf 'Agent context (working tree, %d):\n' "${#TRINKET_CHANGED_PATHS[@]}"
  fi

  printf 'Read first:\n  AGENTS.md\n'
  if (( ${#TRINKET_AGENT_GUIDES[@]} > 0 )); then
    printf '  %s\n' "${TRINKET_AGENT_GUIDES[@]}"
  fi

  printf 'Context cards:\n'
  if (( ${#TRINKET_CONTEXT_CARDS[@]} > 0 )); then
    printf '  %s\n' "${TRINKET_CONTEXT_CARDS[@]}"
  else
    printf '  (none)\n'
  fi
  printf 'Skills:\n'
  if (( ${#TRINKET_SKILLS[@]} > 0 )); then
    printf '  %s\n' "${TRINKET_SKILLS[@]}"
  else
    printf '  (none)\n'
  fi

  if (( ${#TRINKET_AUTHORED_PATHS[@]} > 0 )); then
    printf 'Authored paths:\n  %s\n' "${TRINKET_AUTHORED_PATHS[@]}"
  fi
  if (( ${#TRINKET_GENERATED_PATHS[@]} > 0 )); then
    printf 'Generated/processed paths (do not hand-edit):\n  %s\n' "${TRINKET_GENERATED_PATHS[@]}"
  fi

  printf 'Boundary warnings:\n'
  if (( ${#TRINKET_BOUNDARY_WARNINGS[@]} > 0 )); then
    printf '  %s\n' "${TRINKET_BOUNDARY_WARNINGS[@]}"
  else
    printf '  (none)\n'
  fi
  if (( ${#TRINKET_GENERATED_WARNINGS[@]} > 0 )); then
    printf 'Generated-output warnings:\n  %s\n' "${TRINKET_GENERATED_WARNINGS[@]}"
  fi

  printf 'Verification (agents: always --isolate):\n'
  if [[ "$PATH_MODE" == explicit ]]; then
    printf '  ./Scripts/verify-changed.sh --isolate --paths'
    local path
    for path in "${TRINKET_CHANGED_PATHS[@]}"; do
      printf ' %s' "$path"
    done
    printf '\n'
  else
    printf '  ./Scripts/verify-changed.sh --isolate\n'
  fi
  printf 'Plan detail (sequential under that tenant):\n'
  if (( ${#TRINKET_VERIFICATION_COMMANDS[@]} > 0 )); then
    local cmd
    for cmd in "${TRINKET_VERIFICATION_COMMANDS[@]}"; do
      if [[ "$cmd" == *"./Scripts/test.sh"* \
         || "$cmd" == *"./Scripts/test-package.sh"* \
         || "$cmd" == *"./Scripts/build.sh"* ]]; then
        printf '  TRINKET_ISOLATE=1 %s\n' "$cmd"
      else
        printf '  %s\n' "$cmd"
      fi
    done
  else
    printf '  (none; review docs/tooling directly)\n'
  fi
  if [[ "$TRINKET_SMOKE_TARGET_UNRESOLVED" == true ]]; then
    printf 'UI note: no single smoke owner could be inferred for every path; choose the closest existing Smoke* class or add focused coverage. Do not substitute bare smoke.\n'
  fi
}

if [[ "$OUTPUT" == json ]]; then
  print_json
else
  print_agent
fi
