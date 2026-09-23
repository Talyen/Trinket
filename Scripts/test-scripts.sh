#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/args.sh
source Scripts/lib/args.sh

SKIP_DOCS=false
FAST=false
requested_paths=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-docs) SKIP_DOCS=true ;;
    --fast) FAST=true; SKIP_DOCS=true ;;
    --paths)
      shift
      [[ $# -gt 0 ]] || { echo "--paths requires individual files" >&2; exit 2; }
      requested_paths=("$@")
      break ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/test-scripts.sh [--skip-docs] [--fast] [--paths <file> ...]

Syntax and regression checks for repository scripts. By default also runs
documentation link/inventory checks via check-docs.py; pass --skip-docs when
a caller already ran the docs gate (for example handoff --final).
--fast skips docs, media audio fixtures, and shell regressions for a quick
local loop; CI runs the full suite. Failed logs are retained under RESULTS_DIR
or .DerivedData/ScriptTestResults; terminal excerpts are bounded.
Suites run in parallel (TRINKET_SCRIPT_TEST_JOBS caps workers, default ncpu)
and report in selection order; every selected suite is attempted and the
first failure exits.
--paths selects registered leaf-script regression families. Shared/unknown script
paths and unscoped invocations run all suites. Syntax is scoped to --paths;
cache alignment stays full-tree (cheap static guard). CI uses the unscoped
full suite. --paths consumes remaining arguments.
USAGE
      exit 0
      ;;
    *)
      trinket_args_unknown "$1" "Usage: ./Scripts/test-scripts.sh [--skip-docs] [--fast] [--paths <file> ...]" >&2
      exit 1
      ;;
  esac
  shift
done

if (( ${#requested_paths[@]} > 0 )); then
  # Use the same path validation and normalization as handoff so direct
  # invocations handle in-repository absolute paths for both routing and syntax.
  # shellcheck source=change-classification.sh
  source Scripts/change-classification.sh
  trinket_collect_paths explicit "${requested_paths[@]}"
  requested_paths=("${TRINKET_CHANGED_PATHS[@]}")
fi

selection_args=()
if (( ${#requested_paths[@]} > 0 )); then
  selection_args=(--paths "${requested_paths[@]}")
fi
selection="$(python3 Scripts/script_test_selection.py ${selection_args[@]+"${selection_args[@]}"})"
python_modules=()
shell_suites=()
while IFS= read -r suite; do
  [[ -n "$suite" ]] || continue
  case "$suite" in
    *.py)
      [[ "$FAST" == true && "$suite" == */test_media_asset_scripts.py ]] && continue
      module="${suite##*/}"
      python_modules+=("${module%.py}") ;;
    *.sh)
      [[ "$FAST" == true ]] || shell_suites+=("$suite") ;;
  esac
done <<< "$selection"
printf 'Script scope: %d Python and %d shell suites.\n' "${#python_modules[@]}" "${#shell_suites[@]}"

TEST_LOG_ROOT="${RESULTS_DIR:-$PWD/.DerivedData/ScriptTestResults}"
mkdir -p "$TEST_LOG_ROOT"
TEST_LOG_DIR="$(mktemp -d "$TEST_LOG_ROOT/script-tests.XXXXXX")"
trap 'status=$?; if [[ "$status" -eq 0 ]]; then rm -rf "$TEST_LOG_DIR"; else echo "Script test logs retained: $TEST_LOG_DIR" >&2; fi' EXIT

report_failure() {
  local suite="$1" log="$2" status="$3"
  printf 'FAIL: %s (exit %s)\nFull log: %s\n' "$suite" "$status" "$log" >&2
  python3 Scripts/script_diagnostics.py "$log" || true
  exit "$status"
}

run_logged() {
  local suite="$1" log="$2"
  shift 2
  # Append: TEST_LOG_DIR is fresh per run, and shared logs (syntax) must keep
  # every failure's context instead of only the last one.
  if "$@" >>"$log" 2>&1; then
    return 0
  else
    report_failure "$suite" "$log" "$?"
  fi
}

echo "=== Script syntax ==="
syntax_started=$SECONDS
if (( ${#requested_paths[@]} > 0 )); then
  syntax_list=()
  syntax_skipped=()
  for candidate in "${requested_paths[@]}"; do
    case "$candidate" in
      Scripts/*.sh|Scripts/*.env|Scripts/*.py|Scripts/*.mjs|Scripts/bin/*)
        [[ -f "$candidate" ]] || continue
        syntax_list+=("$candidate") ;;
      *)
        syntax_skipped+=("$candidate") ;;
    esac
  done
  if (( ${#syntax_list[@]} == 0 )); then
    echo "(no syntax-checkable paths selected)"
  else
    printf '%s\n' "${syntax_list[@]}" | LC_ALL=C sort | while IFS= read -r script; do
      case "$script" in
        *.py) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" python3 -c 'import pathlib, sys; compile(pathlib.Path(sys.argv[1]).read_bytes(), sys.argv[1], "exec")' "$script" ;;
        *.mjs) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" node --check "$script" ;;
        Scripts/bin/*) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" sh -n "$script" ;;
        *) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" bash -n "$script" ;;
      esac
    done
  fi
  if (( ${#syntax_skipped[@]} > 0 )); then
    printf 'Syntax scope note: %d selected path(s) live outside Scripts/ and are covered by their own owners, not script syntax.\n' "${#syntax_skipped[@]}" >&2
  fi
else
  while IFS= read -r script; do
    case "$script" in
      *.py) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" python3 -c 'import pathlib, sys; compile(pathlib.Path(sys.argv[1]).read_bytes(), sys.argv[1], "exec")' "$script" ;;
      *.mjs) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" node --check "$script" ;;
      Scripts/bin/*) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" sh -n "$script" ;;
      *) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" bash -n "$script" ;;
    esac
  done < <(rg --files Scripts -g '*.sh' -g '*.env' -g '*.py' -g '*.mjs' -g 'Scripts/bin/*' | LC_ALL=C sort)
fi
printf 'Script syntax passed (%ds).\n' "$((SECONDS - syntax_started))"

echo "=== Python script regressions ==="
python_started=$SECONDS
if (( ${#python_modules[@]} == 0 )); then
  echo "(no Python regressions selected)"
else
  # Suites are independent unittest modules with isolated logs: run them in
  # parallel (same xargs -P shape as test-package.sh) and report in selection
  # order afterwards so output stays deterministic. Unlike the old sequential
  # loop, every selected suite is attempted; the first failure still exits.
  cpu_count="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
  suite_jobs="${TRINKET_SCRIPT_TEST_JOBS:-$cpu_count}"
  [[ "$suite_jobs" =~ ^[0-9]+$ ]] && (( suite_jobs >= 1 )) || suite_jobs=1
  if [[ "$suite_jobs" -gt ${#python_modules[@]} ]]; then suite_jobs=${#python_modules[@]}; fi
  printf '%s\n' "${python_modules[@]}" | TRINKET_TEST_LOG_DIR="$TEST_LOG_DIR" xargs -P "$suite_jobs" -I{} bash -c '
    module="$1"
    log="$TRINKET_TEST_LOG_DIR/python-$module.log"
    started=$SECONDS
    if PYTHONPATH=Scripts/Tests python3 -m unittest -b "$module" >"$log" 2>&1; then
      printf "%s passed (%ds).\n" "$module" "$((SECONDS - started))" >"$log.status"
    else
      printf "%s" "$?" >"$log.failed"
    fi
  ' _ {} || true
  for module in "${python_modules[@]}"; do
    module_log="$TEST_LOG_DIR/python-$module.log"
    if [[ -f "$module_log.failed" ]]; then
      report_failure "Python script regressions: $module" "$module_log" "$(cat "$module_log.failed")"
    else
      cat "$module_log.status"
    fi
  done
  printf 'Python script regressions passed (%ds).\n' "$((SECONDS - python_started))"
fi

echo "=== Shell script regressions ==="
if [[ "$FAST" == true ]]; then
  echo "(fast: shell regressions skipped; full run covers test-*.sh)"
elif (( ${#shell_suites[@]} == 0 )); then
  echo "(no shell regressions selected)"
else
for test_script in "${shell_suites[@]}"; do
  test_name="$(basename "$test_script")"
  test_log="$TEST_LOG_DIR/$test_name.log"
  TRINKET_TEST_LOG_DIR="$TEST_LOG_DIR" test_script="$test_script" test_log="$test_log" bash -c '
    # Subshells inherit the EXIT trap that cleans TEST_LOG_DIR on success;
    # workers must not run it (the parent owns log retention).
    trap - EXIT
    started=$SECONDS
    if bash "$test_script" >"$test_log" 2>&1; then
      printf "%s passed (%ds).\n" "$(basename "$test_script")" "$((SECONDS - started))" >"$test_log.status"
    else
      printf "%s" "$?" >"$test_log.failed"
    fi
  ' &
done
wait || true
for test_script in "${shell_suites[@]}"; do
  test_name="$(basename "$test_script")"
  test_log="$TEST_LOG_DIR/$test_name.log"
  if [[ -f "$test_log.failed" ]]; then
    report_failure "$test_name" "$test_log" "$(cat "$test_log.failed")"
  else
    cat "$test_log.status"
  fi
done
fi

echo "=== Build input / cache-key path alignment ==="
run_logged "Build input / cache-key path alignment" "$TEST_LOG_DIR/cache-paths.log" ./Scripts/check-build-cache-paths.sh

if [[ "$SKIP_DOCS" != true ]]; then
  echo "=== Documentation links and inventory ==="
  run_logged "Documentation links and inventory" "$TEST_LOG_DIR/docs.log" python3 ./Scripts/check-docs.py
fi

echo "=== Script checks passed ==="
