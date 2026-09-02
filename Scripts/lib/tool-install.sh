#!/usr/bin/env bash

# Shared checksummed tarball installer mechanics for .tools/ binaries.
# Tool-specific platform mapping and version policy stay in the owning
# command (ensure-ci-tools.sh, ensure-git-cliff.sh). Callers must set
# TOOLS_DIR before sourcing. Marker format (archive=/binary= sha256 lines)
# is shared so installs stay fresh across the owning commands.

trinket_tool_sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

# 0 when the install marker matches the pinned archive checksum and the
# currently installed binary; callers add their own version check.
trinket_tool_marker_fresh() {
  local name="$1" bin="$2" archive_checksum="$3"
  local marker="$TOOLS_DIR/.$name.sha256"
  [[ -x "$bin" && -f "$marker" ]] \
    && [[ "$(awk -F= '$1 == "archive" { print $2; exit }' "$marker")" == "$archive_checksum" ]] \
    && [[ "$(awk -F= '$1 == "binary" { print $2; exit }' "$marker")" == "$(trinket_tool_sha256_file "$bin")" ]]
}

trinket_tool_write_marker() {
  local name="$1" bin="$2" archive_checksum="$3"
  printf 'archive=%s\nbinary=%s\n' "$archive_checksum" "$(trinket_tool_sha256_file "$bin")" > "$TOOLS_DIR/.$name.sha256"
}

# Downloads and checksum-verifies a tarball; prints the temp dir holding it
# as archive.tar.gz. Callers own cleanup of the printed dir.
trinket_tool_fetch_tarball() {
  local url="$1" checksum="$2" label="$3"
  local tmpdir actual
  tmpdir="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmpdir/archive.tar.gz"
  actual="$(trinket_tool_sha256_file "$tmpdir/archive.tar.gz")"
  if [[ "$actual" != "$checksum" ]]; then
    echo "$label checksum mismatch: expected $checksum, found $actual" >&2
    rm -rf "$tmpdir"
    return 1
  fi
  printf '%s' "$tmpdir"
}
