#!/usr/bin/env bash
# Commit-completeness gate for agents after commit and before push.
# Checks committed generated-output completeness without regenerating or compiling.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh


PATH_MODE="working-tree"
declare -a requested_paths=()

usage() {
  cat <<'EOF'
Usage: ./Scripts/agent-push-gate.sh [--paths <file> ...]

Internal pre-push component: checks that tracked generated outputs have been
committed and reports the change budget. It never regenerates assets or builds.
CI proves generation freshness and idempotence after the push.

Without --paths, unions working-tree paths with local commits not present on a
remote (falling back to the latest commit). With --paths, only those paths drive
the advisory change budget.

Invoked automatically by the pre-push hook; not a manual post-commit step.
The user-facing workflow is focused iteration → path-scoped handoff → commit → push.

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
trinket_require_pinned_tools

trinket_collect_committed_paths() {
  local path
  local remote_refs

  TRINKET_CHANGED_PATHS=()
  remote_refs="$(git for-each-ref --format='%(refname)' refs/remotes)"
  if [[ -n "$remote_refs" ]]; then
    while IFS= read -r path; do
      [[ -n "$path" ]] && TRINKET_CHANGED_PATHS+=("$path")
    done < <(
      git log -m --format= --name-only --diff-filter=ACMRD HEAD --not --remotes |
        sed '/^$/d' |
        sort -u
    )
  fi

  if [[ ${#TRINKET_CHANGED_PATHS[@]} -eq 0 ]]; then
    while IFS= read -r path; do
      [[ -n "$path" ]] && TRINKET_CHANGED_PATHS+=("$path")
    done < <(
      git diff-tree --root --no-commit-id --name-only -m -r --diff-filter=ACMRD HEAD |
        sort -u
    )
  fi
}

if [[ "$PATH_MODE" == explicit ]]; then
  normalized="$(PYTHONPATH=Scripts python3 -m internal.change_routing --paths "${requested_paths[@]}")"
else
  normalized="$(PYTHONPATH=Scripts python3 -m internal.change_routing --working-tree)"
fi
TRINKET_CHANGED_PATHS=()
while IFS= read -r path; do [[ -z "$path" ]] || TRINKET_CHANGED_PATHS+=("$path"); done <<< "$normalized"
if [[ "$PATH_MODE" == "working-tree" ]]; then
  working_paths=("${TRINKET_CHANGED_PATHS[@]-}")
  trinket_collect_committed_paths
  committed_paths=("${TRINKET_CHANGED_PATHS[@]-}")
  TRINKET_CHANGED_PATHS=()
  for path in "${working_paths[@]}" "${committed_paths[@]}"; do
    [[ -n "$path" ]] || continue
    TRINKET_CHANGED_PATHS+=("$path")
  done
fi

report_change_budget() {
  if [[ "$PATH_MODE" == "explicit" ]]; then
    ./Scripts/change-budget.sh --paths "${TRINKET_CHANGED_PATHS[@]}"
  else
    ./Scripts/change-budget.sh
  fi
}

if [[ "$PATH_MODE" == "working-tree" ]]; then
  echo "Commit scope: ${#TRINKET_CHANGED_PATHS[@]} path(s) selected for generation routing."
fi

echo "=== Agent push gate: committed generated outputs ==="
./Scripts/assert-generated-output.sh
report_change_budget
echo "=== Agent push gate passed (static completeness only) ==="
echo "Local asset checks own raw-source freshness; CI owns content generation, prepared-output integrity, compilation, package tests, and UI verification."
