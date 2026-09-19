#!/usr/bin/env bash
set -euo pipefail

# Unit coverage for Scripts/lib/tempdir.sh tracked-tempfile helpers.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../lib/tempdir.sh
source "$ROOT_DIR/Scripts/lib/tempdir.sh"
# shellcheck source=../lib/tempdir.sh
source "$ROOT_DIR/Scripts/lib/tempdir.sh"

fail() {
  echo "test-lib-tempdir.sh FAIL: $*" >&2
  exit 1
}

# trinket_mktemp_dir assigns a tracked directory (no command substitution:
# capturing through $(...) would fork, losing tracking and firing EXIT early).
trinket_mktemp_dir dir trinket-test-tempdir
[[ -d "$dir" ]] || fail "mktemp_dir did not create a directory: $dir"
[[ "$dir" == "${TMPDIR:-/tmp}/trinket-test-tempdir."* ]] || fail "mktemp_dir prefix: $dir"

# trinket_mktemp_file assigns a tracked file.
trinket_mktemp_file file trinket-test-tempfile
[[ -f "$file" ]] || fail "mktemp_file did not create a file: $file"

# trinket_temp_track registers an existing path.
other="$(mktemp -d)"
trinket_temp_track "$other"
[[ ${#TRINKET_TEMP_TRACKED[@]} -eq 3 ]] || fail "tracked count: ${#TRINKET_TEMP_TRACKED[@]}"

# trinket_temp_cleanup_all removes everything tracked and resets.
trinket_temp_cleanup_all
[[ ! -e "$dir" && ! -e "$file" && ! -e "$other" ]] || fail "cleanup_all left paths behind"
[[ ${#TRINKET_TEMP_TRACKED[@]} -eq 0 ]] || fail "tracking array not reset"

# Cleanup is idempotent.
trinket_temp_cleanup_all

# EXIT trap fires: a child shell's tracked path dies with it.
inner_path="$(bash -c "source \"$ROOT_DIR/Scripts/lib/tempdir.sh\" >/dev/null; trinket_mktemp_file inner trinket-test-child; printf '%s' \"\$inner\"")"
[[ -n "$inner_path" ]] || fail "child printed no path"
[[ ! -e "$inner_path" ]] || fail "EXIT trap did not clean child path: $inner_path"

echo "test-lib-tempdir.sh passed"
