#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh

OUTPUT="agent"
PATH_MODE="unset"
FULL=false
ALLOW_BROAD_SCOPE=false
MAX_WORKING_TREE_PATHS="${TRINKET_MAX_WORKING_TREE_PATHS:-40}"
[[ "$MAX_WORKING_TREE_PATHS" =~ ^[0-9]+$ ]] || MAX_WORKING_TREE_PATHS=40
declare -a requested_paths=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) OUTPUT="agent" ;;
    --smoke)
      TRINKET_ENABLE_SMOKE=true
      export TRINKET_ENABLE_SMOKE
      ;;
    --full) FULL=true ;;
    --allow-broad-scope) ALLOW_BROAD_SCOPE=true ;;
    --help|-h)
      cat <<USAGE
Usage: ./Scripts/agent-context.sh [--agent] [--full] [--smoke] [--allow-broad-scope] [--paths <file> ...]

Prints a compact task briefing: applicable AGENTS.md guides, context cards and
skills, architecture/generated-output warnings, and the focused sequential
verification plan. Agents should run the recommended handoff --isolate
command. Paths are repository-relative; --paths consumes all remaining
arguments. Use --working-tree explicitly when the whole tree is intentional.
The default briefing omits empty sections and plan details; --full adds the
authored path inventory, route metadata, and complete verification commands. Whole-tree
classification is capped at ${MAX_WORKING_TREE_PATHS} paths unless explicitly
overridden with --allow-broad-scope.
USAGE
      exit 0
      ;;
    --working-tree)
      PATH_MODE="working-tree"
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

if [[ "$PATH_MODE" == "unset" ]]; then
  echo "agent-context requires --paths <file...>; use --working-tree to classify the whole tree intentionally" >&2
  exit 2
fi

trinket_collect_paths "$PATH_MODE" "${requested_paths[@]-}"
if [[ "$PATH_MODE" == working-tree && "$ALLOW_BROAD_SCOPE" != true \
  && ${#TRINKET_CHANGED_PATHS[@]} -gt "$MAX_WORKING_TREE_PATHS" ]]; then
  echo "working-tree scope has ${#TRINKET_CHANGED_PATHS[@]} paths; use explicit --paths or --allow-broad-scope" >&2
  exit 3
fi
trinket_classify_paths
trinket_build_verification_plan

print_agent() {
  if [[ "$PATH_MODE" == explicit ]]; then
    printf 'Agent context (explicit paths, %d):\n' "${#TRINKET_CHANGED_PATHS[@]}"
  else
    printf 'Agent context (working tree, %d):\n' "${#TRINKET_CHANGED_PATHS[@]}"
  fi

  printf 'Read first (reuse unchanged guidance already in context):\n  AGENTS.md\n'
  if (( ${#TRINKET_AGENT_GUIDES[@]} > 0 )); then
    printf '  %s\n' "${TRINKET_AGENT_GUIDES[@]}"
  fi
  if (( ${#TRINKET_CONTEXT_CARDS[@]} > 0 )); then
    printf 'Context cards:\n'
    printf '  %s\n' "${TRINKET_CONTEXT_CARDS[@]}"
  fi
  if [[ "$FULL" == true ]] && (( ${#TRINKET_ROUTE_CARDS[@]} > 0 )); then
    printf 'Route metadata (lookup only):\n'
    printf '  %s\n' "${TRINKET_ROUTE_CARDS[@]}"
  fi
  local skill trigger
  if (( ${#TRINKET_SKILLS[@]} > 0 )); then
    printf 'Skills (load only when the trigger applies):\n'
    for skill in "${TRINKET_SKILLS[@]}"; do
      case "$skill" in
        */apple-design/*) trigger='visual or interaction changes' ;;
        */architect/*) trigger='public type, protocol, schema, or package boundary changes' ;;
        */doc-budget/*) trigger='Swift comments or comment-gate failures' ;;
        *) trigger='see skill description' ;;
      esac
      printf '  %s — %s\n' "$skill" "$trigger"
    done
  fi
  if (( ${#TRINKET_KNOWLEDGE[@]} > 0 )); then
    printf 'Memory (only for its concern):\n'
    printf '  %s\n' "${TRINKET_KNOWLEDGE[@]}"
  fi

  print_path_summary() {
    local label="$1"
    shift
    local count=$#
    (( count > 0 )) || return 0
    printf '%s (%d):\n' "$label" "$count"
    if (( count <= 8 )); then
      printf '  %s\n' "$@"
      return 0
    fi
    printf '%s\n' "$@" | awk -F/ '
      {
        key = $1
        if (($1 == "Docs" || $1 == "Packages" || $1 == "Trinket") && NF > 1) key = $1 "/" $2
        counts[key]++
      }
      END { for (key in counts) printf "  %s: %d path(s)\n", key, counts[key] }
    ' | sort
  }

  if [[ "$FULL" == true ]] && (( ${#TRINKET_AUTHORED_PATHS[@]} > 0 )); then
    print_path_summary 'Authored paths' "${TRINKET_AUTHORED_PATHS[@]}"
  fi
  if (( ${#TRINKET_GENERATED_PATHS[@]} > 0 )); then
    print_path_summary 'Generated/processed paths (do not hand-edit)' "${TRINKET_GENERATED_PATHS[@]}"
  fi

  if (( ${#TRINKET_BOUNDARY_WARNINGS[@]} > 0 )); then
    printf 'Boundary warnings:\n'
    printf '  %s\n' "${TRINKET_BOUNDARY_WARNINGS[@]}"
  fi
  if (( ${#TRINKET_GENERATED_WARNINGS[@]} > 0 )); then
    printf 'Generated-output warnings:\n'
    printf '  %s\n' "${TRINKET_GENERATED_WARNINGS[@]}"
  fi

  printf 'Verification (agents: always --isolate):\n'
  if [[ "$PATH_MODE" == explicit ]]; then
    printf '  ./Scripts/handoff.sh --isolate --paths'
    local path
    for path in "${TRINKET_CHANGED_PATHS[@]}"; do printf ' %q' "$path"; done
    printf '\n'
  else
    printf '  ./Scripts/handoff.sh --isolate --working-tree\n'
  fi
  if [[ "$FULL" == true ]] && (( ${#TRINKET_VERIFICATION_COMMANDS[@]} > 0 )); then
    printf 'Plan detail (sequential under that tenant):\n'
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
  fi
  if [[ "$TRINKET_SMOKE_TARGET_UNRESOLVED" == true ]]; then
    printf 'UI note: no single smoke owner was inferred. Apply the Testing rubric; add coverage only for a qualifying unique shipping outcome. Do not substitute bare smoke.\n'
  fi
  if [[ "$TRINKET_APP_COMPILE_SKIPPED_NO_XCODE" == true ]]; then
    printf 'Compile note: app compile tier skipped (no xcodebuild). Style PASS is not compile-clean — report the skip; CI build-for-testing owns Swift 6 / macro errors.\n'
  fi
}

print_agent
