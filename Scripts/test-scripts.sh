#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SKIP_DOCS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-docs) SKIP_DOCS=true ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/test-scripts.sh [--skip-docs]

Syntax and regression checks for repository scripts. By default also runs
documentation link/inventory checks via check-docs.py; pass --skip-docs when
a caller already ran the docs gate (for example handoff --final).
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
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
if python3 -m unittest discover -b -s Scripts/Tests -p 'test*.py' >"$python_log" 2>&1; then
  echo "Python script regressions passed."
else
  cat "$python_log" >&2
  exit 1
fi

echo "=== Shell script regressions ==="
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

echo "=== Build input / cache-key path alignment ==="
./Scripts/check-build-cache-paths.sh

if [[ "$SKIP_DOCS" != true ]]; then
  echo "=== Documentation links and inventory ==="
  python3 ./Scripts/check-docs.py
fi

echo "=== Script checks passed ==="
