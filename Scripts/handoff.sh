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

TRINKET_PROFILE_STARTED_AT="$(date -u '+%Y-%m-%dT%H:%M:%S.000+00:00')"

report_output_profile() {
  local status=$?
  trap - EXIT
  if [[ "${TRINKET_OUTPUT_PROFILE:-1}" != "0" ]]; then
    python3 Scripts/output-profile.py report --local --actionable \
      --since "$TRINKET_PROFILE_STARTED_AT" --top 3 \
      || echo "Warning: output profile report unavailable." >&2
  fi
  exit "$status"
}

trap report_output_profile EXIT

# Run a routed check through the output profiler while leaving command output
# and the command's exit status under the profiler's control. The profiler is
# intentionally invoked for every check; TRINKET_OUTPUT_PROFILE=0 remains the
# documented debugging escape hatch for callers that need the old direct path.
run_profiled() {
  local label="$1"
  local policy="$2"
  shift 2
  python3 Scripts/output-profile.py run --label "$label" --policy "$policy" -- "$@"
}

# check_run <kind> <argument>
run_check() {
  local kind="$1"
  local argument="$2"
  case "$kind" in
    generate)
      case "$argument" in
        normal) run_profiled "generate" "live" ./Scripts/generate.sh ;;
        assets) run_profiled "generate-assets" "live" ./Scripts/generate.sh --assets ;;
        *) echo "Unknown generate check: $argument" >&2; return 2 ;;
      esac
      ;;
    assert)
      case "$argument" in
        idempotent) run_profiled "assert-generated-output" "live" ./Scripts/assert-generated-output.sh --idempotent ;;
        idempotent-assets) run_profiled "assert-generated-output-assets" "live" ./Scripts/assert-generated-output.sh --idempotent --assets ;;
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
        run_profiled "test-smoke" "quiet-structured" env SKIP_GENERATE=1 ./Scripts/test.sh smoke "${smoke_targets[@]}"
      elif [[ "$argument" == style:* ]]; then
        local -a style_paths=()
        # shellcheck disable=SC2206
        style_paths=(${argument#style:})
        run_profiled "test-style" "quiet-structured" ./Scripts/test.sh style "${style_paths[@]}"
      elif [[ "$argument" == style ]]; then
        run_profiled "test-style" "quiet-structured" ./Scripts/test.sh style
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
      run_profiled "test-package" "quiet-structured" env SKIP_GENERATE=1 ./Scripts/test-package.sh "${packages[@]}"
      ;;
    build)
      [[ "$argument" == app ]] || { echo "Unknown build check: $argument" >&2; return 2; }
      run_profiled "build-app" "quiet-structured" env SKIP_GENERATE=1 ./Scripts/build.sh
      ;;
    scripts)
      [[ "$argument" == all ]] || { echo "Unknown script check: $argument" >&2; return 2; }
      if [[ "$FINAL" == true ]]; then
        run_profiled "test-scripts" "quiet-structured" ./Scripts/test-scripts.sh --skip-docs
      else
        run_profiled "test-scripts" "quiet-structured" ./Scripts/test-scripts.sh
      fi
      ;;
    docs)
      [[ "$argument" == check ]] || { echo "Unknown docs check: $argument" >&2; return 2; }
      run_profiled "check-docs" "live" python3 ./Scripts/check-docs.py
      ;;
    *)
      echo "Unknown verification kind: $kind" >&2; return 2
      ;;
  esac
}

run_cheap_ci_slices() {
  run_profiled "module-boundaries" "quiet-structured" ./Scripts/check-module-boundaries.sh
  run_profiled "swift-testing-migration" "quiet-structured" ./Scripts/check-swift-testing-migration.sh
  run_profiled "release-notes-validate" "quiet-structured" ./Scripts/release-notes.sh validate
  run_profiled "artwork-budget" "quiet-structured" ./Scripts/check-artwork-budget.sh
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
    --final) FINAL=true ;;
    --keep-plan) KEEP_PLAN=true ;;
    --working-tree) PATH_MODE="working-tree" ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/handoff.sh [--dry-run] [--quiet] [--isolate] [--final] [--keep-plan] [--paths <file> ...]

Classifies task-scoped changes when --paths is supplied, otherwise all
working-tree changes. It runs generation, style, touched-package tests, an
app build for unresolved feature/UI Swift, and a targeted smoke canary —
sequentially, with no demotions or warm-cache reuse.

--isolate forwards to the simulator-slot environment (test/test-package) so a
task-scoped run does not collide with another agent on the same Mac. Agents
should always pass --isolate.
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
  run_profiled "documentation" "live" python3 ./Scripts/check-docs.py "${docs_args[@]}"
fi

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
  echo "=== Cheap CI slices (boundaries, Swift Testing, release notes) ==="
fi
run_cheap_ci_slices

exit 0
