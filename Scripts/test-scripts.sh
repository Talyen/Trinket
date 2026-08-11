#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

TEST_LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_LOG_DIR"' EXIT

echo "=== Script syntax ==="
while IFS= read -r script; do
  bash -n "$script"
done < <(find Scripts -type f -name '*.sh' -print | LC_ALL=C sort)

echo "=== Python script regressions ==="
python_log="$TEST_LOG_DIR/python.log"
if python3 -m unittest discover -s Scripts/Tests -p 'test*.py' >"$python_log" 2>&1; then
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
done < <(find Scripts/Tests -maxdepth 1 -type f -name 'test-*.sh' -print | LC_ALL=C sort)

echo "=== Build input / cache-key path alignment ==="
./Scripts/check-build-cache-paths.sh

echo "=== Documentation links and inventory ==="
python3 ./Scripts/check-docs.py

echo "=== Script checks passed ==="
