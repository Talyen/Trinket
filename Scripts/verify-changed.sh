#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Keep source routing aligned with changed-source-summary.sh and
# agent-context.sh.
# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh
# shellcheck source=Scripts/run-env.sh
source Scripts/run-env.sh
# shellcheck source=Scripts/swift-source-dirs.env
source Scripts/swift-source-dirs.env

DRY_RUN=false
ISOLATE=false
PUSH_READY=false
QUIET=false
PATH_MODE="working-tree"
declare -a requested_paths=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --quiet) QUIET=true ;;
    --isolate)
      ISOLATE=true
      TRINKET_ISOLATE=1
      export TRINKET_ISOLATE
      ;;
    --push-ready)
      # Commit completeness: force XcodeGen + assert vs HEAD (not --idempotent).
      PUSH_READY=true
      TRINKET_PUSH_READY=true
      export TRINKET_PUSH_READY
      TRINKET_REQUIRE_PINNED_TOOLS=1
      export TRINKET_REQUIRE_PINNED_TOOLS
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/verify-changed.sh [--dry-run] [--quiet] [--isolate] [--push-ready] [--paths <file> ...]

Classifies task-scoped changes when --paths is supplied, otherwise all working-tree
changes. It runs any required generation once, then the smallest focused
verification commands. Style and package checks may run in parallel; multi-smoke
and multi-package targets are batched into single invocations.

--isolate acquires a reusable agent simulator slot (Trinket Agent N) with
DerivedData under .DerivedData/runs/agent-N/ so this verification does not
collide with another agent on the same Mac. Agents should always pass --isolate.
Humans and CI may omit it to keep the shared warm cache (.DerivedData + Trinket CI).
On EXIT and at self-clean start, the top-level owner reclaims non-empty Preview
sims (shutdown Booted, then delete), enforces exactly one Booted managed sim
(Agent or CI), and age-prunes bulky DerivedData / package build artifacts. The
keep-target stays Booted (no routine erase).
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

run_change_budget() {
  if [[ "$PATH_MODE" == "explicit" ]]; then
    ./Scripts/change-budget.sh --paths "${TRINKET_CHANGED_PATHS[@]}"
  else
    ./Scripts/change-budget.sh
  fi
}

if [[ ${#TRINKET_CHANGED_PATHS[@]} -eq 0 ]]; then
  if [[ "$PUSH_READY" == true ]]; then
    echo "No working-tree changes; running agent-push-gate for commit completeness."
    if [[ "$DRY_RUN" == true ]]; then
      echo "Would run: ./Scripts/agent-push-gate.sh"
      exit 0
    fi
    exec ./Scripts/agent-push-gate.sh
  fi
  echo "No working-tree changes to verify."
  exit 0
fi

if [[ "$PUSH_READY" == true ]]; then
  echo "=== Push-ready: ensuring pinned tools ==="
  if [[ "$DRY_RUN" == false ]]; then
    ./Scripts/ensure-ci-tools.sh
    export PATH="$PWD/.tools:$PATH"
  fi
fi

trinket_classify_paths
trinket_build_verification_plan
commands=()
if (( ${#TRINKET_VERIFICATION_COMMANDS[@]} > 0 )); then commands=("${TRINKET_VERIFICATION_COMMANDS[@]}"); fi
kinds=()
arguments=()
if (( ${#TRINKET_VERIFICATION_KINDS[@]} > 0 )); then kinds=("${TRINKET_VERIFICATION_KINDS[@]}"); fi
if (( ${#TRINKET_VERIFICATION_ARGS[@]} > 0 )); then arguments=("${TRINKET_VERIFICATION_ARGS[@]}"); fi
smoke_target_unresolved="$TRINKET_SMOKE_TARGET_UNRESOLVED"
app_compile_skipped_no_xcode="$TRINKET_APP_COMPILE_SKIPPED_NO_XCODE"

if [[ ${#commands[@]} -eq 0 ]]; then
  if [[ "$PUSH_READY" == true ]]; then
    echo "No source verification selected; falling back to agent-push-gate."
    if [[ "$DRY_RUN" == true ]]; then
      echo "Would run: ./Scripts/agent-push-gate.sh"
      exit 0
    fi
    exec ./Scripts/agent-push-gate.sh
  fi
  echo "No source verification selected for the current changes."
  if [[ "$smoke_target_unresolved" == true ]]; then
    echo "UI note: no single smoke owner was inferred. Apply the Testing rubric; add coverage only for a qualifying unique shipping outcome. Do not substitute bare smoke."
  else
    echo "Review docs/tooling changes directly; use ci-gate or a task-specific command when appropriate."
  fi
  if [[ "$app_compile_skipped_no_xcode" == true ]]; then
    echo "Compile note: app compile tier skipped (no xcodebuild). Style PASS is not compile-clean — report the skip; CI build-for-testing owns Swift 6 / macro errors."
  fi
  run_change_budget
  # Docs/tooling-only plans still self-clean when --isolate (no slot acquire).
  if [[ "$ISOLATE" == true && "$DRY_RUN" != true ]]; then
    TRINKET_SIM_SLOT_SKIP_ACQUIRE=1 trinket_run_env_init
    trinket_run_env_self_clean_hygiene
  fi
  exit 0
fi

echo "Verification plan (${#commands[@]} check(s)):"
printf '  %s\n' "${commands[@]}"
if [[ "$smoke_target_unresolved" == true ]]; then
  echo "UI note: no single smoke owner was inferred. Apply the Testing rubric; add coverage only for a qualifying unique shipping outcome. Do not substitute bare smoke."
fi
if [[ "$app_compile_skipped_no_xcode" == true ]]; then
  echo "Compile note: app compile tier skipped (no xcodebuild). Style PASS is not compile-clean — report the skip; CI build-for-testing owns Swift 6 / macro errors."
fi
if [[ "$DRY_RUN" == true ]]; then
  if [[ "$ISOLATE" == true ]]; then
    TRINKET_SIM_SLOT_SKIP_ACQUIRE=1 trinket_run_env_init
    trinket_run_env_print
  fi
  echo "Would report: ./Scripts/change-budget.sh"
  exit 0
fi

if [[ "$ISOLATE" == true ]]; then
  trinket_run_env_init
  trinket_run_env_print
  # Export tenant env so every structured child shares one agent slot + DerivedData.
  export TRINKET_ISOLATE TRINKET_RUN_ID DERIVED_DATA_PATH RESULTS_DIR
  export TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TMPDIR TMP TEMP
  export TRINKET_DIAGNOSTICS_SESSION_ID TRINKET_UI_ACTIVE_DIR TRINKET_SIM_ACTIVE_DIR
  export TRINKET_MAX_CONCURRENT_UI TRINKET_MAX_AGENT_SIMS
  # Parent owns self-clean on EXIT (Preview reclaim, idle-pool, age-prune).
  # Nested test children inherit the owner token and must not overwrite it.
  trinket_run_env_install_self_clean
fi

# shellcheck source=Scripts/build-stamp.sh
source Scripts/build-stamp.sh
# Needed so touch_build_stamp records a fresh gitstatus sidecar for --no-build.
# shellcheck source=Scripts/build-inputs.sh
source Scripts/build-inputs.sh

VERIFY_TIMING_LOG="${RESULTS_DIR:-$PWD/.DerivedData/TestResults}/verify-timing.jsonl"
mkdir -p "$(dirname "$VERIFY_TIMING_LOG")"
VERIFY_WALL_START=$SECONDS
APP_PRODUCTS_WARMED=false
SHARED_SIM_DESTINATION=""
APP_PREFETCH_PID=""
APP_PREFETCH_LOG=""

cleanup_app_prefetch() {
  if [[ -n "$APP_PREFETCH_PID" ]]; then
    if kill -0 "$APP_PREFETCH_PID" 2>/dev/null; then
      kill "$APP_PREFETCH_PID" 2>/dev/null || true
      wait "$APP_PREFETCH_PID" 2>/dev/null || true
    fi
    APP_PREFETCH_PID=""
  fi
  if [[ -n "$APP_PREFETCH_LOG" ]]; then
    rm -f "$APP_PREFETCH_LOG"
    APP_PREFETCH_LOG=""
  fi
}

quiet_log=""
if [[ "$QUIET" == true ]]; then
  quiet_log=$(mktemp -t trinket-verify.XXXXXX)
fi
# Compose EXIT trap: always stop orphan prefetch; keep isolate self-clean / quiet cleanup.
if [[ "$ISOLATE" == true && "$QUIET" == true ]]; then
  trap 'cleanup_app_prefetch; rm -f "$quiet_log"; trinket_run_env_release_slots' EXIT INT TERM
elif [[ "$ISOLATE" == true ]]; then
  trap 'cleanup_app_prefetch; trinket_run_env_release_slots' EXIT INT TERM
elif [[ "$QUIET" == true ]]; then
  trap 'cleanup_app_prefetch; rm -f "$quiet_log"' EXIT INT TERM
else
  trap 'cleanup_app_prefetch' EXIT INT TERM
fi

record_verify_stage() {
  local display="$1"
  local kind="$2"
  local status="$3"
  local wall="$4"
  python3 - "$VERIFY_TIMING_LOG" "$display" "$kind" "$status" "$wall" <<'PY'
import json, sys
from datetime import datetime, timezone
path, display, kind, status, wall = sys.argv[1:6]
entry = {
    "schema_version": 1,
    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "display": display,
    "kind": kind,
    "status": int(status),
    "wall_seconds": float(wall),
}
with open(path, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(entry, separators=(",", ":")) + "\n")
PY
}

stamp_generate_if_needed() {
  # Records generation-input porcelain so idempotent assert can skip a second
  # full regenerate in dirty agent worktrees (mtime + snapshot, not dirty-vs-HEAD).
  # shellcheck source=Scripts/build-inputs.sh
  source Scripts/build-inputs.sh
  touch_generate_stamp "${RESULTS_DIR:-$PWD/.DerivedData/TestResults}"
}

ensure_shared_simulator() {
  if [[ -n "$SHARED_SIM_DESTINATION" ]]; then
    return 0
  fi
  # shellcheck source=Scripts/ensure-simulator.sh
  source Scripts/ensure-simulator.sh
  ensure_test_simulator_logged
  SHARED_SIM_DESTINATION="$SIMULATOR_DESTINATION"
  export SIMULATOR_DESTINATION="$SHARED_SIM_DESTINATION"
}

warm_app_products_if_needed() {
  # Multiple app consumers: one build-for-testing, then --no-build.
  local app_consumers=0
  local argument
  for argument in "${arguments[@]}"; do
    case "$argument" in
      unit|smoke:*)
        app_consumers=$((app_consumers + 1))
        ;;
    esac
  done
  if (( app_consumers < 2 )); then
    return 0
  fi
  echo ""
  echo "=== Warm app products (build-for-testing --app-only) ==="
  SKIP_GENERATE=1 ./Scripts/build-for-testing.sh --app-only
  # Path-scoped unit is --app-only; stamp unit so --no-build is accepted.
  touch_build_stamp "${RESULTS_DIR:-$PWD/.DerivedData/TestResults}" unit
  APP_PRODUCTS_WARMED=true
}

count_app_consumers() {
  local app_consumers=0
  local argument
  for argument in "${arguments[@]+"${arguments[@]}"}"; do
    case "$argument" in
      unit|smoke:*)
        app_consumers=$((app_consumers + 1))
        ;;
    esac
  done
  printf '%s\n' "$app_consumers"
}

plan_has_package_parallel() {
  local index
  for index in "${parallel_indices[@]+"${parallel_indices[@]}"}"; do
    case "${kinds[$index]}" in
      package|package-build) return 0 ;;
    esac
  done
  return 1
}

plan_has_smoke() {
  local argument
  for argument in "${arguments[@]+"${arguments[@]}"}"; do
    case "$argument" in
      smoke:*) return 0 ;;
    esac
  done
  return 1
}

should_prefetch_app_during_parallel() {
  [[ "$APP_PRODUCTS_WARMED" != true ]] || return 1
  plan_has_smoke || return 1
  plan_has_package_parallel || return 1
  # unit+smoke still uses the sequential warm path after parallel work.
  (( $(count_app_consumers) < 2 )) || return 1
  return 0
}

start_app_build_prefetch() {
  should_prefetch_app_during_parallel || return 0
  APP_PREFETCH_LOG=$(mktemp -t trinket-verify-prefetch.XXXXXX)
  echo ""
  echo "=== Prefetch app products (build-for-testing --app-only, background) ==="
  (
    SKIP_GENERATE=1 ./Scripts/build-for-testing.sh --app-only
  ) >"$APP_PREFETCH_LOG" 2>&1 &
  APP_PREFETCH_PID=$!
}

finish_app_build_prefetch() {
  [[ -n "$APP_PREFETCH_PID" ]] || return 0
  local pid="$APP_PREFETCH_PID"
  local log="$APP_PREFETCH_LOG"
  APP_PREFETCH_PID=""
  if wait "$pid"; then
    APP_PRODUCTS_WARMED=true
    if [[ "$QUIET" == true ]]; then
      echo "PASS: prefetch build-for-testing --app-only"
    else
      echo ""
      echo "=== Prefetch build-for-testing --app-only ==="
      cat "$log"
    fi
    rm -f "$log"
    APP_PREFETCH_LOG=""
    return 0
  fi
  echo "WARN: app product prefetch failed; smoke will rebuild"
  tail -n "${TRINKET_VERIFY_FAILURE_LINES:-40}" "$log" || true
  rm -f "$log"
  APP_PREFETCH_LOG=""
  return 0
}

# Reuse a prior isolate-slot build-for-testing when stamps + build-input gitstatus
# are still fresh (mid-task / second handoff). Prefetch covers the cold first run.
try_reuse_warm_app_products() {
  [[ "$APP_PRODUCTS_WARMED" != true ]] || return 0
  plan_has_smoke || return 0

  local results_dir="${RESULTS_DIR:-$PWD/.DerivedData/TestResults}"
  local built_app="${DERIVED_DATA_PATH:-$PWD/.DerivedData}/Build/Products/Debug-iphonesimulator/Trinket.app"
  [[ -d "$built_app" ]] || return 0

  local argument
  local targets_string
  local target
  local fingerprint
  local stamp
  for argument in "${arguments[@]+"${arguments[@]}"}"; do
    case "$argument" in
      smoke:*)
        targets_string="${argument#smoke:}"
        # shellcheck disable=SC2206
        local -a smoke_targets=($targets_string)
        for target in "${smoke_targets[@]}"; do
          fingerprint="smoke_${target}"
          stamp="$(build_stamp_path "$results_dir" "$fingerprint")"
          if ! assert_no_build_inputs_are_fresh "$stamp" "$fingerprint" >/dev/null 2>&1; then
            return 0
          fi
        done
        ;;
    esac
  done

  echo ""
  echo "=== Reusing warm app products (--no-build) ==="
  APP_PRODUCTS_WARMED=true
}

valid_package_name() {
  local candidate="$1"
  local package
  for package in "${TRINKET_TEST_PACKAGES[@]}"; do
    if [[ "$package" == "$candidate" ]]; then
      return 0
    fi
  done
  return 1
}

run_verification_command() {
  local kind="$1"
  local argument="$2"
  case "$kind" in
    generate)
      case "$argument" in
        normal) ./Scripts/generate.sh ;;
        assets) ./Scripts/generate.sh --assets ;;
        force) ./Scripts/generate.sh --force-xcodegen ;;
        assets-force) ./Scripts/generate.sh --assets --force-xcodegen ;;
        *) echo "Unknown structured generate check: $argument" >&2; return 2 ;;
      esac
      stamp_generate_if_needed
      ;;
    assert)
      case "$argument" in
        committed) ./Scripts/assert-generated-output.sh ;;
        assets) ./Scripts/assert-generated-output.sh --assets ;;
        idempotent) ./Scripts/assert-generated-output.sh --idempotent ;;
        idempotent-assets) ./Scripts/assert-generated-output.sh --idempotent --assets ;;
        *) echo "Unknown structured assert check: $argument" >&2; return 2 ;;
      esac
      stamp_generate_if_needed
      ;;
    test)
      if [[ "$argument" == smoke:* ]]; then
        local targets_string="${argument#smoke:}"
        local -a smoke_targets=()
        local target
        # shellcheck disable=SC2206
        smoke_targets=($targets_string)
        for target in "${smoke_targets[@]}"; do
          [[ "$target" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid smoke target: $target" >&2; return 2; }
        done
        ensure_shared_simulator
        local smoke_args=(smoke)
        if [[ "$APP_PRODUCTS_WARMED" == true ]]; then
          smoke_args+=(--no-build)
        fi
        smoke_args+=("${smoke_targets[@]}")
        SKIP_GENERATE=1 ./Scripts/test.sh "${smoke_args[@]}"
      elif [[ "$argument" == style ]]; then
        ./Scripts/test.sh style
      elif [[ "$argument" == style:* ]]; then
        local paths_string="${argument#style:}"
        local -a style_paths=()
        # shellcheck disable=SC2206
        style_paths=($paths_string)
        ./Scripts/test.sh style "${style_paths[@]}"
      elif [[ "$argument" == unit ]]; then
        ensure_shared_simulator
        local unit_args=(unit --app-only)
        if [[ "$APP_PRODUCTS_WARMED" == true ]]; then
          unit_args+=(--no-build)
        fi
        SKIP_GENERATE=1 ./Scripts/test.sh "${unit_args[@]}"
      else
        echo "Unknown structured test check: $argument" >&2
        return 2
      fi
      ;;
    package)
      local -a packages=()
      local package
      # shellcheck disable=SC2206
      packages=($argument)
      (( ${#packages[@]} > 0 )) || { echo "Empty package list" >&2; return 2; }
      for package in "${packages[@]}"; do
        valid_package_name "$package" || { echo "Unknown structured package check: $package" >&2; return 2; }
      done
      ensure_shared_simulator
      SKIP_GENERATE=1 ./Scripts/test-package.sh --destination "$SHARED_SIM_DESTINATION" "${packages[@]}"
      ;;
    package-build)
      local -a packages=()
      local package
      # shellcheck disable=SC2206
      packages=($argument)
      (( ${#packages[@]} > 0 )) || { echo "Empty package-build list" >&2; return 2; }
      for package in "${packages[@]}"; do
        valid_package_name "$package" || { echo "Unknown structured package-build check: $package" >&2; return 2; }
      done
      ensure_shared_simulator
      SKIP_GENERATE=1 ./Scripts/test-package.sh --build-only --destination "$SHARED_SIM_DESTINATION" "${packages[@]}"
      ;;
    build)
      [[ "$argument" == app ]] || { echo "Unknown structured build check: $argument" >&2; return 2; }
      SKIP_GENERATE=1 ./Scripts/build.sh
      ;;
    *)
      echo "Unknown structured verification kind: $kind" >&2
      return 2
      ;;
  esac
}

run_one_indexed_check() {
  local index="$1"
  local command="${commands[$index]}"
  local kind="${kinds[$index]:-}"
  local argument="${arguments[$index]:-}"
  local stage_start=$SECONDS
  local status=0
  if [[ -z "$kind" ]]; then
    echo "Missing structured verification metadata for: $command" >&2
    return 2
  fi
  if [[ "$QUIET" == true ]]; then
    if run_verification_command "$kind" "$argument" > "$quiet_log" 2>&1; then
      echo "PASS: $command"
    else
      status=$?
      echo "FAIL: $command"
      tail -n "${TRINKET_VERIFY_FAILURE_LINES:-80}" "$quiet_log"
      record_verify_stage "$command" "$kind" "$status" "$((SECONDS - stage_start))"
      return "$status"
    fi
  else
    echo ""
    echo "=== $command ==="
    run_verification_command "$kind" "$argument" || status=$?
  fi
  record_verify_stage "$command" "$kind" "$status" "$((SECONDS - stage_start))"
  return "$status"
}

# Partition: generate/assert first (sequential), then style∥packages, then the rest.
declare -a gen_assert_indices=()
declare -a parallel_indices=()
declare -a rest_indices=()
for index in "${!commands[@]}"; do
  case "${kinds[$index]}" in
    generate|assert)
      gen_assert_indices+=("$index")
      ;;
    test)
      if [[ "${arguments[$index]}" == style || "${arguments[$index]}" == style:* ]]; then
        parallel_indices+=("$index")
      else
        rest_indices+=("$index")
      fi
      ;;
    package|package-build)
      parallel_indices+=("$index")
      ;;
    *)
      rest_indices+=("$index")
      ;;
  esac
done

for index in "${gen_assert_indices[@]+"${gen_assert_indices[@]}"}"; do
  run_one_indexed_check "$index"
done

# Boot once before parallel package work so children share a destination.
for index in "${parallel_indices[@]+"${parallel_indices[@]}"}"; do
  if [[ "${kinds[$index]}" == package || "${kinds[$index]}" == package-build ]]; then
    ensure_shared_simulator
    break
  fi
done

start_app_build_prefetch

if (( ${#parallel_indices[@]} > 1 )); then
  echo ""
  echo "=== Parallel: style and package checks ==="
  declare -a parallel_pids=()
  declare -a parallel_logs=()
  declare -a parallel_labels=()
  for index in "${parallel_indices[@]}"; do
    log=$(mktemp -t trinket-verify-p.XXXXXX)
    parallel_logs+=("$log")
    parallel_labels+=("${commands[$index]}")
    (
      stage_start=$SECONDS
      status=0
      run_verification_command "${kinds[$index]}" "${arguments[$index]}" >"$log" 2>&1 || status=$?
      record_verify_stage "${commands[$index]}" "${kinds[$index]}" "$status" "$((SECONDS - stage_start))"
      exit "$status"
    ) &
    parallel_pids+=("$!")
  done
  parallel_status=0
  for i in "${!parallel_pids[@]}"; do
    if wait "${parallel_pids[$i]}"; then
      if [[ "$QUIET" == true ]]; then
        echo "PASS: ${parallel_labels[$i]}"
      else
        echo ""
        echo "=== ${parallel_labels[$i]} (parallel) ==="
        cat "${parallel_logs[$i]}"
      fi
    else
      status=$?
      parallel_status=$status
      echo "FAIL: ${parallel_labels[$i]}"
      tail -n "${TRINKET_VERIFY_FAILURE_LINES:-80}" "${parallel_logs[$i]}"
    fi
    rm -f "${parallel_logs[$i]}"
  done
  if [[ "$parallel_status" -ne 0 ]]; then
    cleanup_app_prefetch
    exit "$parallel_status"
  fi
elif (( ${#parallel_indices[@]} == 1 )); then
  run_one_indexed_check "${parallel_indices[0]}"
fi

finish_app_build_prefetch
try_reuse_warm_app_products
warm_app_products_if_needed

for index in "${rest_indices[@]+"${rest_indices[@]}"}"; do
  run_one_indexed_check "$index"
done

echo ""
echo "Verify wall: $((SECONDS - VERIFY_WALL_START))s (stages → $VERIFY_TIMING_LOG)"

run_change_budget
