#!/usr/bin/env bash
set -euo pipefail

# The canonical task-scoped handoff gate.
#
# Classifies the changed paths (explicit --paths or the whole working tree),
# builds a deterministic sequential verification plan, and runs it in order.
# No demotions, no heuristics, no parallel scheduling, no warm-cache prefetch:
# the plan is whatever the touched paths actually require, executed top to
# bottom. Remote/full confidence is owned by CI (smoke-full / exhaustive UI).

cd "$(dirname "$0")/.."

# Keep source routing aligned with agent-context.sh and agent-push-gate.sh.
# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh
# shellcheck source=Scripts/swift-source-dirs.env
source Scripts/swift-source-dirs.env

DRY_RUN=false
ISOLATE=false
QUIET=false
PATH_MODE="working-tree"
declare -a requested_paths=()

# check_run <kind> <argument>
run_check() {
  local kind="$1"
  local argument="$2"
  case "$kind" in
    generate)
      case "$argument" in
        normal) ./Scripts/generate.sh ;;
        assets) ./Scripts/generate.sh --assets ;;
        *) echo "Unknown generate check: $argument" >&2; return 2 ;;
      esac
      ;;
    assert)
      case "$argument" in
        committed) ./Scripts/assert-generated-output.sh ;;
        assets) ./Scripts/assert-generated-output.sh --assets ;;
        idempotent) ./Scripts/assert-generated-output.sh --idempotent ;;
        idempotent-assets) ./Scripts/assert-generated-output.sh --idempotent --assets ;;
        *) echo "Unknown assert check: $argument" >&2; return 2 ;;
      esac
      ;;
    test)
      if [[ "$argument" == smoke:* ]]; then
        local -a smoke_targets=()
        # shellcheck disable=SC2206
        smoke_targets=(${argument#smoke:})
        for target in "${smoke_targets[@]}"; do
          [[ "$target" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid smoke target: $target" >&2; return 2; }
        done
        SKIP_GENERATE=1 ./Scripts/test.sh smoke "${smoke_targets[@]}"
      elif [[ "$argument" == style:* ]]; then
        local -a style_paths=()
        # shellcheck disable=SC2206
        style_paths=(${argument#style:})
        ./Scripts/test.sh style "${style_paths[@]}"
      elif [[ "$argument" == style ]]; then
        ./Scripts/test.sh style
      else
        echo "Unknown test check: $argument" >&2; return 2
      fi
      ;;
    package)
      local -a packages=()
      # shellcheck disable=SC2206
      packages=($argument)
      local package
      for package in "${packages[@]}"; do
        local valid=false
        local candidate
        for candidate in "${TRINKET_TEST_PACKAGES[@]}"; do
          if [[ "$candidate" == "$package" ]]; then valid=true; break; fi
        done
        [[ "$valid" == true ]] || { echo "Unknown package: $package" >&2; return 2; }
      done
      SKIP_GENERATE=1 ./Scripts/test-package.sh "${packages[@]}"
      ;;
    build)
      [[ "$argument" == app ]] || { echo "Unknown build check: $argument" >&2; return 2; }
      SKIP_GENERATE=1 ./Scripts/build.sh
      ;;
    scripts)
      [[ "$argument" == all ]] || { echo "Unknown script check: $argument" >&2; return 2; }
      ./Scripts/test-scripts.sh
      ;;
    *)
      echo "Unknown verification kind: $kind" >&2; return 2
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --quiet) QUIET=true ;;
    --isolate)
      ISOLATE=true
      TRINKET_ISOLATE=1
      export TRINKET_ISOLATE
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/handoff.sh [--dry-run] [--quiet] [--isolate] [--paths <file> ...]

Classifies task-scoped changes when --paths is supplied, otherwise all
working-tree changes. It runs generation, style, touched-package tests, an
app build for unresolved feature/UI Swift, app unit tests, and a targeted
smoke canary — sequentially, with no demotions or warm-cache reuse.

--isolate forwards to the simulator-slot environment (test/test-package) so a
task-scoped run does not collide with another agent on the same Mac. Agents
should always pass --isolate.
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
  echo "No working-tree changes to verify."
  exit 0
fi

trinket_classify_paths
trinket_build_verification_plan

if [[ "$DRY_RUN" == true ]]; then
  echo "Planned checks:"
  if (( ${#TRINKET_VERIFICATION_COMMANDS[@]} > 0 )); then
    printf '  %s\n' "${TRINKET_VERIFICATION_COMMANDS[@]}"
  else
    echo "  (none; review docs/tooling directly)"
  fi
  exit 0
fi

if (( ${#TRINKET_VERIFICATION_COMMANDS[@]} > 0 )); then
  for i in "${!TRINKET_VERIFICATION_COMMANDS[@]}"; do
    cmd="${TRINKET_VERIFICATION_COMMANDS[$i]}"
    kind="${TRINKET_VERIFICATION_KINDS[$i]:-}"
    argument="${TRINKET_VERIFICATION_ARGS[$i]:-}"
    if [[ "$QUIET" != true ]]; then
      echo ""
      echo "=== $cmd ==="
    fi
    if ! run_check "$kind" "$argument"; then
      echo "FAIL: $cmd"
      exit 1
    fi
  done
  if [[ "$QUIET" != true ]]; then
    echo ""
    echo "Handoff select: review the run output above."
  fi
else
  echo "No source verification selected for the current changes."
  if [[ "$TRINKET_SMOKE_TARGET_UNRESOLVED" == true ]]; then
    echo "UI note: no smoke owner was inferred for the changed feature path. CI smoke-full / exhaustive UI remain the broad net."
  fi
fi

exit 0
