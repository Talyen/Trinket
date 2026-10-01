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
Python and shell suites share a parallel worker pool
(TRINKET_SCRIPT_TEST_JOBS caps workers, default ncpu)
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
syntax_list=()
syntax_skipped=()
if (( ${#requested_paths[@]} > 0 )); then
  for candidate in "${requested_paths[@]}"; do
    case "$candidate" in
      Scripts/*.sh|Scripts/*.env|Scripts/*.py|Scripts/*.mjs|Scripts/bin/*)
        [[ -f "$candidate" ]] || continue
        syntax_list+=("$candidate") ;;
      *)
        syntax_skipped+=("$candidate") ;;
    esac
  done
else
  while IFS= read -r script; do
    syntax_list+=("$script")
  done < <(rg --files Scripts -g '*.sh' -g '*.env' -g '*.py' -g '*.mjs' -g 'Scripts/bin/*' | LC_ALL=C sort)
fi
if (( ${#syntax_skipped[@]} > 0 )); then
  printf 'Syntax scope note: %d selected path(s) live outside Scripts/ and are covered by their own owners, not script syntax.\n' "${#syntax_skipped[@]}" >&2
fi
python_syntax=()
for script in "${syntax_list[@]}"; do
  case "$script" in
    *.py) python_syntax+=("$script") ;;
    *.mjs) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" node --check "$script" ;;
    Scripts/bin/*) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" sh -n "$script" ;;
    *) run_logged "Syntax: $script" "$TEST_LOG_DIR/syntax.log" bash -n "$script" ;;
  esac
done
# Compile without importing fixtures or writing bytecode; one interpreter for all files.
if (( ${#python_syntax[@]} > 0 )); then
  run_logged "Python syntax" "$TEST_LOG_DIR/syntax.log" python3 -c '
import pathlib, sys
for name in sys.argv[1:]:
    compile(pathlib.Path(name).read_bytes(), name, "exec")
' "${python_syntax[@]}"
fi
printf 'Script syntax passed (%ds).\n' "$((SECONDS - syntax_started))"

echo "=== Script regressions ==="
regressions_started=$SECONDS
# Start shell watchdog cases alongside Python modules instead of adding their
# real timeout waits to the end of the Python phase. All fixtures are isolated.
suites=("${shell_suites[@]}" "${python_modules[@]}")
if (( ${#suites[@]} == 0 )); then
  echo "(no regressions selected)"
else
  cpu_count="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
  suite_jobs="${TRINKET_SCRIPT_TEST_JOBS:-$cpu_count}"
  [[ "$suite_jobs" =~ ^[0-9]+$ ]] && (( suite_jobs >= 1 )) || suite_jobs=1
  if [[ "$suite_jobs" -gt ${#suites[@]} ]]; then suite_jobs=${#suites[@]}; fi
  printf '%s\n' "${suites[@]}" | TRINKET_TEST_LOG_DIR="$TEST_LOG_DIR" xargs -P "$suite_jobs" -I{} bash -c '
    suite="$1"
    log="$TRINKET_TEST_LOG_DIR/${suite##*/}.log"
    started=$SECONDS
    case "$suite" in
      *.sh) command=(bash "$suite") ;;
      *) command=(python3 -m unittest -b "$suite") ;;
    esac
    status=0
    PYTHONPATH=Scripts/Tests "${command[@]}" >"$log" 2>&1 || status=$?
    printf "%s\n" "$status" >"$log.exit"
    printf "%s passed (%ds).\n" "${suite##*/}" "$((SECONDS - started))" >"$log.status"
  ' _ {} || true
  # Keep diagnostics deterministic and attempt every suite before reporting
  # the first failure, including a worker that died without recording its exit.
  for suite in "${python_modules[@]}" "${shell_suites[@]}"; do
    suite_log="$TEST_LOG_DIR/${suite##*/}.log"
    status=1
    if [[ -f "$suite_log.exit" ]]; then status="$(cat "$suite_log.exit")"; fi
    if [[ "$status" != 0 ]]; then
      report_failure "Script regressions: $suite" "$suite_log" "$status"
    fi
    cat "$suite_log.status"
  done
  printf 'Script regressions passed (%ds).\n' "$((SECONDS - regressions_started))"
fi

echo "=== Build input / cache-key path alignment ==="
run_logged "Build input / cache-key path alignment" "$TEST_LOG_DIR/cache-paths.log" ./Scripts/check-build-cache-paths.sh

if [[ "$SKIP_DOCS" != true ]]; then
  echo "=== Documentation links and inventory ==="
  run_logged "Documentation links and inventory" "$TEST_LOG_DIR/docs.log" python3 ./Scripts/check-docs.py
fi

echo "=== Script checks passed ==="
