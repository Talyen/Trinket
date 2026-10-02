#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh

OUTPUT="agent"
PATH_MODE="unset"
FULL=false
STATUS=false
FINGERPRINTS=false
RECEIPT=""
CHAT=""
SESSION=""
TASK=""
READ_COMMAND=false
EXPLICIT_TASK_PATHS=false
ALLOW_BROAD_SCOPE=false
MAX_WORKING_TREE_PATHS="${TRINKET_MAX_WORKING_TREE_PATHS:-40}"
[[ "$MAX_WORKING_TREE_PATHS" =~ ^[0-9]+$ ]] || MAX_WORKING_TREE_PATHS=40
usage_error() {
  printf '%s\n' "$1" "Try: ./Scripts/agent-context.sh --help" >&2
  exit "${2:-2}"
}

declare -a requested_paths=()
declare -a task_contracts=()
TASK_LABEL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) OUTPUT="agent" ;;
    --smoke)
      TRINKET_ENABLE_SMOKE=true
      export TRINKET_ENABLE_SMOKE
      ;;
    --full) FULL=true ;;
    --status) STATUS=true ;;
    --read-command) READ_COMMAND=true ;;
    --fingerprints) FINGERPRINTS=true ;;
    --receipt|--chat|--session|--task)
      [[ $# -ge 2 && -n "$2" ]] || { usage_error "$1 requires a value"; }
      case "$1" in
        --receipt) RECEIPT="$2" ;; --chat) CHAT="$2" ;;
        --session) SESSION="$2" ;; --task) TASK="$2" ;;
      esac
      shift
      ;;
    --allow-broad-scope) ALLOW_BROAD_SCOPE=true ;;
    --help|-h)
      cat <<USAGE
Usage: ./Scripts/agent-context.sh [--agent] [--full] [--status] [--task CONCERN] [--session CHAT_ID | --receipt FILE --chat ID] [--fingerprints] [--smoke] [--allow-broad-scope] [--paths <file> ...]

Prints a compact task briefing: applicable AGENTS.md guides, context cards and
skills, architecture/generated-output warnings, and the focused sequential
verification plan. Agents should run the recommended handoff --isolate
command. In-repository paths are normalized; --paths consumes all remaining
arguments. Use --working-tree explicitly when the whole tree is intentional.
The default briefing omits empty sections and plan details; --full adds the
authored path inventory, route metadata, and complete verification commands. Whole-tree
classification is capped at ${MAX_WORKING_TREE_PATHS} paths unless explicitly
overridden with --allow-broad-scope.
--status adds global dirty counts by owner and exact Git status for supplied files,
including both rename endpoints. Inspect overlapping diffs before editing;
status does not establish ownership of another task's work.
--fingerprints adds whole-file SHA-256 identities for guides, cards, skills, and
knowledge. Reuse only references actually read in this chat with matching hashes;
unchanged hashes do not establish that guidance was read or that a trigger applies.
--receipt FILE --chat ID annotates guidance actually read by agent-read in this
chat. Put both options before --paths. All references and warnings remain visible.
--task CONCERN highlights indexed contract sections; without --paths it routes
the concern's sources. Explicit paths still determine the complete safety/check route.
--session CHAT_ID derives a temporary receipt for this chat and repository.
Use agent-session.py to supply the current CODEX_THREAD_ID automatically.
--read-command prints only the executable initial-guidance read for --task.
USAGE
      exit 0
      ;;
    --working-tree)
      PATH_MODE="working-tree"
      ;;
    --paths)
      EXPLICIT_TASK_PATHS=true
      PATH_MODE="explicit"
      shift
      if [[ $# -eq 0 ]]; then
        usage_error "--paths requires at least one repository-relative path" 1
      fi
      requested_paths=("$@")
      break
      ;;
    *)
      usage_error "Unknown argument: $1" 1
      ;;
  esac
  shift
done

if [[ -n "$SESSION" ]]; then
  [[ -z "$RECEIPT" && -z "$CHAT" ]] || { usage_error "--session cannot combine with --receipt or --chat"; }
  CHAT="$SESSION"
  RECEIPT="$(PYTHONPATH=Scripts python3 -m internal.agent_references --session "$SESSION")"
fi

if [[ -n "$TASK" ]]; then
  [[ "$PATH_MODE" != working-tree ]] || { usage_error "--task cannot combine with --working-tree; use --paths for the actual task scope"; }
  TASK_LABEL="$(PYTHONPATH=Scripts python3 -m internal.agent_tasks "$TASK" --field label)"
  task_references="$(PYTHONPATH=Scripts python3 -m internal.agent_tasks "$TASK" --field contracts)"
  while IFS= read -r reference; do task_contracts+=("$reference"); done <<< "$task_references"
  if [[ "$PATH_MODE" == unset ]]; then
    task_sources="$(PYTHONPATH=Scripts python3 -m internal.agent_tasks "$TASK" --field sources)"
    while IFS= read -r path; do requested_paths+=("$path"); done <<< "$task_sources"
    PATH_MODE="explicit"
  fi
fi

if [[ -n "$RECEIPT" && -z "$CHAT" || -z "$RECEIPT" && -n "$CHAT" ]]; then
  usage_error "--receipt and --chat must be supplied together"
fi

if [[ "$PATH_MODE" == "unset" ]]; then
  usage_error "agent-context requires --paths <file...>; use --working-tree to classify the whole tree intentionally"
fi

trinket_collect_paths "$PATH_MODE" "${requested_paths[@]-}"
if [[ "$PATH_MODE" == working-tree && "$ALLOW_BROAD_SCOPE" != true \
  && ${#TRINKET_CHANGED_PATHS[@]} -gt "$MAX_WORKING_TREE_PATHS" ]]; then
  usage_error "working-tree scope has ${#TRINKET_CHANGED_PATHS[@]} paths; use explicit --paths or --allow-broad-scope" 3
fi
if [[ "$STATUS" == true ]]; then
  python3 Scripts/internal/agent_status.py "${TRINKET_CHANGED_PATHS[@]+"${TRINKET_CHANGED_PATHS[@]}"}"
fi
trinket_classify_paths
trinket_build_verification_plan

# Presentation taxonomy for the briefing below (sole consumer): behavior cards
# are read for relevant sections while ownership cards carry applicable
# constraints. Kept here, next to the split/trigger/search-root rendering,
# instead of the shared router so classification stays routing-only.
TRINKET_BEHAVIOR_CARDS=(
  Docs/AgentContext/battle-damage.md
  Docs/AgentContext/battle-actions.md
  Docs/AgentContext/battle-healing.md
  Docs/AgentContext/battle-talents.md
  Docs/AgentContext/battle-balance.md
  Docs/AgentContext/battle-launch.md
  Docs/AgentContext/battle-presentation.md
  Docs/AgentContext/persistence-storage.md
  Docs/AgentContext/persistence-progression.md
  Docs/AgentContext/ui-performance.md
)

trinket_is_behavior_card() {
  local card="${1%%#*}" candidate
  for candidate in "${TRINKET_BEHAVIOR_CARDS[@]}"; do
    [[ "$candidate" == "$card" ]] && return 0
  done
  return 1
}

trinket_skill_trigger_for() {
  case "$1" in
    */apple-design/*) printf 'visual or interaction changes' ;;
    */architect/*) printf 'public type, protocol, schema, or package boundary changes' ;;
    */doc-budget/*) printf 'checker directives or suppression failures' ;;
    *) printf 'see skill description' ;;
  esac
}

# Prints the discovery search root for a changed path; returns 1 when the path
# has no scoped root.
trinket_search_root_for_path() {
  local path="$1" package
  case "$path" in
    Packages/*)
      package="${path#Packages/}"; package="${package%%/*}"
      printf 'Packages/%s' "$package" ;;
    Scripts/*) printf 'Scripts' ;;
    Trinket/*|TrinketUITests/*) printf 'Trinket' ;;
    *) return 1 ;;
  esac
}

task_read_command() {
  local card
  local -a read_arguments=("$TASK" --field read-command)
  for card in "${TRINKET_AGENT_GUIDES[@]+"${TRINKET_AGENT_GUIDES[@]}"}" "${TRINKET_CONTEXT_CARDS[@]+"${TRINKET_CONTEXT_CARDS[@]}"}"; do
    trinket_is_behavior_card "$card" && continue
    read_arguments+=(--guide "$card")
  done
  [[ -z "$CHAT" ]] || read_arguments+=(--chat "$CHAT")
  [[ -z "$RECEIPT" ]] || read_arguments+=(--receipt "$RECEIPT")
  PYTHONPATH=Scripts python3 -m internal.agent_tasks "${read_arguments[@]}"
}

if [[ "$READ_COMMAND" == true ]]; then
  [[ -n "$TASK" && "$STATUS" != true ]] || usage_error "--read-command requires --task and cannot combine with --status"
  task_read_command
  exit 0
fi

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
  if (( ${#task_contracts[@]} > 0 )); then
    printf 'Concern focus: %s (routed ownership/behavior; follow relevant callers/sections):\n' "$TASK_LABEL"
    printf '  %s\n' "${task_contracts[@]}"
  fi
  if (( ${#TRINKET_CONTEXT_CARDS[@]} > 0 )); then
    local -a ownership_cards=() behavior_cards=()
    local card
    for card in "${TRINKET_CONTEXT_CARDS[@]}"; do
      local focused=false reference
      for reference in "${task_contracts[@]+"${task_contracts[@]}"}"; do
        [[ "$reference" != "$card" ]] || focused=true
      done
      [[ "$focused" != true ]] || continue
      if trinket_is_behavior_card "$card"; then
        behavior_cards+=("$card")
      else
        ownership_cards+=("$card")
      fi
    done
    if (( ${#ownership_cards[@]} > 0 )); then
      printf 'Ownership and integration (read applicable constraints):\n'
      printf '  %s\n' "${ownership_cards[@]}"
    fi
    if (( ${#behavior_cards[@]} > 0 )); then
      printf 'Behavior references (read relevant sections and follow dependencies):\n'
      printf '  %s\n' "${behavior_cards[@]}"
    fi
  fi
  if [[ "$FULL" == true ]] && (( ${#TRINKET_ROUTE_CARDS[@]} > 0 )); then
    printf 'Route metadata (lookup only):\n'
    printf '  %s\n' "${TRINKET_ROUTE_CARDS[@]}"
  fi
  local skill trigger
  if (( ${#TRINKET_SKILLS[@]} > 0 )); then
    printf 'Skills (load only when the trigger applies):\n'
    for skill in "${TRINKET_SKILLS[@]}"; do
      trigger="$(trinket_skill_trigger_for "$skill")"
      printf '  %s — %s\n' "$skill" "$trigger"
    done
  fi
  if (( ${#TRINKET_KNOWLEDGE[@]} > 0 )); then
    printf 'Memory (only for its concern):\n'
    printf '  %s\n' "${TRINKET_KNOWLEDGE[@]}"
  fi

  if [[ -n "$TASK" ]]; then
    printf 'Suggested initial reads (root already injected; follow other relevant behavior and skill references):\n  '
    if [[ -n "$RECEIPT" && -z "$SESSION" ]]; then
      task_read_command
    else
      PYTHONPATH=Scripts python3 - "$TASK" "$CHAT" "$EXPLICIT_TASK_PATHS" "${TRINKET_CHANGED_PATHS[@]+"${TRINKET_CHANGED_PATHS[@]}"}" <<'PYCOMMAND'
import shlex, sys
task, chat, explicit, *paths = sys.argv[1:]
command = ['python3', 'Scripts/agent-session.py']
if chat:
    command += ['--chat', chat]
command += ['read', '--task', task]
if explicit == 'true':
    command += ['--paths', *paths]
print(shlex.join(command))
PYCOMMAND
    fi
  fi

  if [[ "$FINGERPRINTS" == true ]]; then
    printf 'Reference fingerprints (whole-file identity; not read receipts):\n'
    PYTHONPATH=Scripts python3 -m internal.agent_references AGENTS.md \
      "${TRINKET_AGENT_GUIDES[@]+"${TRINKET_AGENT_GUIDES[@]}"}" \
      "${TRINKET_CONTEXT_CARDS[@]+"${TRINKET_CONTEXT_CARDS[@]}"}" \
      "${task_contracts[@]+"${task_contracts[@]}"}" \
      "${TRINKET_SKILLS[@]+"${TRINKET_SKILLS[@]}"}" \
      "${TRINKET_KNOWLEDGE[@]+"${TRINKET_KNOWLEDGE[@]}"}"
  fi

  local search_root path
  local -a search_roots=()
  for path in "${TRINKET_CHANGED_PATHS[@]+"${TRINKET_CHANGED_PATHS[@]}"}"; do
    if search_root="$(trinket_search_root_for_path "$path")"; then
      trinket_add_unique search_roots "$search_root"
    fi
  done
  if (( ${#search_roots[@]} > 0 )); then
    printf 'Discovery: filename regex (--glob for shell patterns); --related for source/test symbol hints; --excerpts for lines:\n'
    for search_root in "${search_roots[@]}"; do
      printf '  python3 Scripts/agent-search.py --files "<pattern>" --scope %q\n' "$search_root"
      case "$search_root" in
        Packages/*) printf '  source/tests: %s (test mode includes support targets)\n' "$search_root" ;;
        Scripts) printf '  source: Scripts; tests: Scripts/Tests\n' ;;
        Trinket) printf '  source: Trinket; tests: TrinketUITests\n' ;;
      esac
    done
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
    printf '  ./Scripts/handoff.sh --isolate --quiet --paths'
    local path
    for path in "${TRINKET_CHANGED_PATHS[@]}"; do printf ' %q' "$path"; done
    printf '\n'
  else
    printf '  ./Scripts/handoff.sh --isolate --quiet --working-tree\n'
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

if [[ -n "$RECEIPT" ]]; then
  print_agent | PYTHONPATH=Scripts python3 -m internal.agent_references \
    --annotate --receipt "$RECEIPT" --chat "$CHAT" AGENTS.md \
    "${TRINKET_AGENT_GUIDES[@]+"${TRINKET_AGENT_GUIDES[@]}"}" \
    "${TRINKET_CONTEXT_CARDS[@]+"${TRINKET_CONTEXT_CARDS[@]}"}" \
    "${task_contracts[@]+"${task_contracts[@]}"}" \
    "${TRINKET_SKILLS[@]+"${TRINKET_SKILLS[@]}"}" \
    "${TRINKET_KNOWLEDGE[@]+"${TRINKET_KNOWLEDGE[@]}"}"
else
  print_agent
fi
