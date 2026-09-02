#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/args.sh
source Scripts/lib/args.sh

SKIP_DOCS=false
FAST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-docs) SKIP_DOCS=true ;;
    --fast) FAST=true; SKIP_DOCS=true ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/test-scripts.sh [--skip-docs] [--fast]

Syntax and regression checks for repository scripts. By default also runs
documentation link/inventory checks via check-docs.py; pass --skip-docs when
a caller already ran the docs gate (for example handoff --final).
--fast skips docs and the slowest shell fixtures (audio-encode media tests)
for a quick local loop; CI runs the full suite.
USAGE
      exit 0
      ;;
    *)
      trinket_args_unknown "$1" "Usage: ./Scripts/test-scripts.sh [--skip-docs] [--fast]" >&2
      exit 1
      ;;
  esac
  shift
done

TEST_LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_LOG_DIR"' EXIT

echo "=== Script syntax ==="
while IFS= read -r script; do
  bash -n "$script"
done < <(rg --files Scripts -g '*.sh' | LC_ALL=C sort)

echo "=== Python script regressions ==="
python_log="$TEST_LOG_DIR/python.log"
if [[ "$FAST" == true ]]; then
  # Fast loop skips the slowest fixture-heavy module (media audio encodes);
  # full mode and CI still run it.
  if PYTHONPATH=Scripts/Tests python3 -m unittest -b test_agent_context test_aggregate_performance test_check_unused_assets test_ci_path_filter test_ci_verification_scripts test_compare_performance test_content_and_policy_scripts test_failure_diagnostics test_release_notes_user test_test_timing test_verification_improvements test_exec_wrappers >"$python_log" 2>&1; then
    echo "Python script regressions passed (fast: media audio fixtures skipped)."
  else
    cat "$python_log" >&2
    exit 1
  fi
elif python3 -m unittest discover -b -s Scripts/Tests -p 'test*.py' >"$python_log" 2>&1; then
  echo "Python script regressions passed."
else
  cat "$python_log" >&2
  exit 1
fi

echo "=== Shell script regressions ==="
if [[ "$FAST" == true ]]; then
  echo "(fast: shell regressions skipped; full run covers test-*.sh)"
else
while IFS= read -r test_script; do
  test_name="$(basename "$test_script")"
  test_log="$TEST_LOG_DIR/$test_name.log"
  if bash "$test_script" >"$test_log" 2>&1; then
    echo "$test_name passed."
  else
    cat "$test_log" >&2
    exit 1
  fi
done < <(rg --files Scripts/Tests -g 'test-*.sh' | LC_ALL=C sort)
fi

echo "=== Build input / cache-key path alignment ==="
./Scripts/check-build-cache-paths.sh

if [[ "$SKIP_DOCS" != true ]]; then
  echo "=== Documentation links and inventory ==="
  python3 ./Scripts/check-docs.py
fi

echo "=== Script checks passed ==="
