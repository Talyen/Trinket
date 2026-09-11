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
--paths selects registered leaf-script regression families. Shared/unknown script
paths and unscoped invocations run all suites. Syntax and cache alignment stay
full-tree. CI uses the unscoped full suite. --paths consumes remaining arguments.
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
  if "$@" >"$log" 2>&1; then
    return 0
  else
    report_failure "$suite" "$log" "$?"
  fi
}

echo "=== Script syntax ==="
while IFS= read -r script; do
  case "$script" in
    *.py) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" python3 -c 'import pathlib, sys; compile(pathlib.Path(sys.argv[1]).read_bytes(), sys.argv[1], "exec")' "$script" ;;
    *.mjs) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" node --check "$script" ;;
    Scripts/bin/*) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" sh -n "$script" ;;
    *) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" bash -n "$script" ;;
  esac
done < <(rg --files Scripts -g '*.sh' -g '*.env' -g '*.py' -g '*.mjs' -g 'Scripts/bin/*' | LC_ALL=C sort)

echo "=== Python script regressions ==="
python_log="$TEST_LOG_DIR/python.log"
if (( ${#python_modules[@]} == 0 )); then
  echo "(no Python regressions selected)"
elif PYTHONPATH=Scripts/Tests python3 -m unittest -b "${python_modules[@]}" >"$python_log" 2>&1; then
  echo "Python script regressions passed."
else
  report_failure "Python script regressions" "$python_log" "$?"
fi

echo "=== Shell script regressions ==="
if [[ "$FAST" == true ]]; then
  echo "(fast: shell regressions skipped; full run covers test-*.sh)"
else
for test_script in ${shell_suites[@]+"${shell_suites[@]}"}; do
  test_name="$(basename "$test_script")"
  test_log="$TEST_LOG_DIR/$test_name.log"
  if bash "$test_script" >"$test_log" 2>&1; then
    echo "$test_name passed."
  else
    report_failure "$test_name" "$test_log" "$?"
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
