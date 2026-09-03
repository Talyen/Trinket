#!/usr/bin/env bash
set -euo pipefail

# The canonical task-scoped handoff gate.
#
# Classifies the changed paths (explicit --paths or the whole working tree),
# builds a deterministic sequential verification plan, and runs it in order.
# No demotions, no heuristics, no parallel scheduling, no warm-cache prefetch:
# the plan is whatever the touched paths actually require, executed top to
# bottom. Remote/full confidence is owned by CI (smoke / exhaustive UI).

cd "$(dirname "$0")/.."

if [[ -z "${TRINKET_DIAGNOSTICS_SESSION_ID:-}" ]]; then
  TRINKET_DIAGNOSTICS_SESSION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM:-0}"
  export TRINKET_DIAGNOSTICS_SESSION_ID
fi

# Keep source routing aligned with agent-context.sh and agent-push-gate.sh.
# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh
# shellcheck source=Scripts/swift-source-dirs.env
source Scripts/swift-source-dirs.env

DRY_RUN=false
ISOLATE=false
QUIET=false
FINAL=false
KEEP_PLAN=false
PATH_MODE="unset"
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
        env SKIP_GENERATE=1 ./Scripts/test.sh smoke "${smoke_targets[@]}"
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
      env SKIP_GENERATE=1 ./Scripts/test-package.sh "${packages[@]}"
      ;;
    build)
      [[ "$argument" == app ]] || { echo "Unknown build check: $argument" >&2; return 2; }
      env SKIP_GENERATE=1 ./Scripts/build.sh
      ;;
    scripts)
      [[ "$argument" == all ]] || { echo "Unknown script check: $argument" >&2; return 2; }
      if [[ "$FINAL" == true ]]; then
        ./Scripts/test-scripts.sh --skip-docs
      elif [[ "$TRINKET_NEEDS_DOCS" == true ]]; then
        ./Scripts/test-scripts.sh --skip-docs
      else
        ./Scripts/test-scripts.sh
      fi
      ;;
    docs)
      [[ "$argument" == check ]] || { echo "Unknown docs check: $argument" >&2; return 2; }
      python3 ./Scripts/check-docs.py
      ;;
    *)
      echo "Unknown verification kind: $kind" >&2; return 2
      ;;
  esac
}

run_cheap_ci_slices() {
  # shellcheck source=Scripts/lib/cheap-slices.sh
  source Scripts/lib/cheap-slices.sh
  trinket_run_cheap_slices
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
    --smoke)
      TRINKET_ENABLE_SMOKE=true
      export TRINKET_ENABLE_SMOKE
      ;;
    --mirror)
      TRINKET_ENABLE_MIRROR=true
      export TRINKET_ENABLE_MIRROR
      ;;
    --final) FINAL=true ;;
    --keep-plan) KEEP_PLAN=true ;;
    --working-tree) PATH_MODE="working-tree" ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/handoff.sh [--dry-run] [--quiet] [--isolate] [--smoke] [--mirror] [--final] [--keep-plan] [--paths <file> ...]

Classifies task-scoped changes when --paths is supplied, otherwise all
working-tree changes. It runs generation, style, touched-package tests, and
an app build for unresolved or feature/UI Swift — sequentially and headlessly
by default.

--smoke opts into the targeted simulator UI smoke canary for touched feature flows.
--mirror opts into auto-mirroring the built app into Trinket Run on success.
--isolate forwards to the simulator-slot environment so runs do not collide.
--final applies final documentation and active-plan checks.
--keep-plan permits an intentionally unfinished active plan with --final.
Use --working-tree to opt into whole-tree classification; --paths is preferred.
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

if [[ "$PATH_MODE" == "unset" ]]; then
  echo "handoff requires --paths <file...>; use --working-tree to classify the whole tree intentionally" >&2
  exit 2
fi

trinket_collect_paths "$PATH_MODE" "${requested_paths[@]-}"

if [[ "$FINAL" == true ]]; then
  docs_args=("--final")
  [[ "$KEEP_PLAN" == true ]] && docs_args+=("--keep-plan")
  python3 ./Scripts/check-docs.py "${docs_args[@]}"
fi

if [[ ${#TRINKET_CHANGED_PATHS[@]} -eq 0 ]]; then
  echo "No working-tree changes to verify."
  exit 0
fi

trinket_classify_paths
trinket_build_verification_plan

if [[ "$DRY_RUN" == true ]]; then
  # shellcheck source=Scripts/lib/cheap-slices.sh
  source Scripts/lib/cheap-slices.sh
  echo "Planned checks:"
  declare -a _dry_commands=()
  if [[ "$FINAL" == true ]]; then
    _final_docs="python3 ./Scripts/check-docs.py --final"
    [[ "$KEEP_PLAN" == true ]] && _final_docs+=" --keep-plan"
    _dry_commands+=("$_final_docs")
  fi
  _has_docs_in_plan=false
  for _k in "${TRINKET_VERIFICATION_KINDS[@]-}"; do
    [[ "$_k" == docs ]] && _has_docs_in_plan=true && break
  done
  for i in "${!TRINKET_VERIFICATION_COMMANDS[@]}"; do
    kind="${TRINKET_VERIFICATION_KINDS[$i]:-}"
    display="${TRINKET_VERIFICATION_COMMANDS[$i]}"
    if [[ "$kind" == docs && "$FINAL" == true ]]; then
      continue
    fi
    if [[ "$kind" == scripts && ( "$FINAL" == true || "$_has_docs_in_plan" == true ) ]]; then
      _dry_commands+=("./Scripts/test-scripts.sh --skip-docs")
    else
      _dry_commands+=("$display")
    fi
  done
  while IFS= read -r _slice; do
    [[ -n "$_slice" ]] && _dry_commands+=("$_slice")
  done < <(trinket_run_cheap_slices --dry-run)
  if (( ${#_dry_commands[@]} > 0 )); then
    printf '  %s\n' "${_dry_commands[@]}"
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
    if [[ "$kind" == docs && "$FINAL" == true ]]; then
      # --final already ran check-docs.py with plan-lifecycle flags.
      continue
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
    echo "UI note: no smoke owner was inferred for the changed feature path. CI smoke / exhaustive UI remain the broad net."
  fi
fi

if [[ "$QUIET" != true ]]; then
  echo ""
  echo "=== Cheap CI slices (boundaries, Swift Testing, release notes, artwork budget) ==="
fi
run_cheap_ci_slices

if [[ "${TRINKET_ENABLE_MIRROR:-false}" == "true" && "${TRINKET_ISOLATE:-}" == "1" && "${ISOLATE}" == true ]]; then
  _mirror_needs_build=false
  if [[ "$TRINKET_NEEDS_APP_BUILD" == true || "$TRINKET_HAS_FEATURE" == true || "$TRINKET_NEEDS_CONTENT_GENERATION" == true || "$TRINKET_NEEDS_PROJECT_GENERATION" == true ]] || (( ${#TRINKET_PACKAGES[@]} > 0 )); then
    _mirror_needs_build=true
  fi
  if [[ "$_mirror_needs_build" == true ]]; then
    if [[ "$QUIET" == true ]]; then
      ./Scripts/promote.sh --quiet || true
    else
      ./Scripts/promote.sh || true
    fi
  fi
fi

exit 0
