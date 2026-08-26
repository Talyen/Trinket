#!/usr/bin/env bash

# Shared mechanics for manifest-driven media preparation. Manifest-specific
# validation and generated Swift rendering stay in their owning scripts.
# Validation helpers return non-zero instead of exiting; callers run under
# `set -e` and must treat a non-zero return as fatal, not as a condition.

trinket_asset_escape_swift_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

trinket_asset_validate_identifier() {
  local label="$1" value="$2"
  if [[ ! "$value" =~ ^[A-Za-z0-9_][A-Za-z0-9_-]*$ ]]; then
    echo "$label '$value' should use letters, numbers, hyphens, or underscores, and start with a letter, number, or underscore." >&2
    return 1
  fi
}

trinket_asset_validate_swift_identifier() {
  local label="$1" value="$2"
  if [[ ! "$value" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "$label '$value' should be a Swift identifier." >&2
    return 1
  fi
  case "$value" in
    Any|Protocol|Self|Type|actor|any|as|associatedtype|async|await|borrowing|break|case|catch|class|consuming|continue|default|defer|deinit|do|each|else|enum|extension|fallthrough|false|fileprivate|for|func|guard|if|import|in|init|inout|internal|is|isolated|let|macro|nil|nonisolated|open|operator|package|precedencegroup|private|protocol|public|repeat|rethrows|return|self|some|static|struct|subscript|super|switch|throw|throws|true|try|typealias|var|where|while)
      echo "$label '$value' is a reserved Swift keyword." >&2
      return 1
      ;;
  esac
}

trinket_asset_needs_reencode() {
  local recorded_hash="$1"
  local source_hash="$2"
  local recorded_profile="$3"
  local encode_profile="$4"
  local output_file="$5"

  [[ "${FORCE_ASSET_REENCODE:-0}" == "1" ]] \
    || [[ ! -f "$output_file" ]] \
    || [[ -z "$recorded_hash" ]] \
    || [[ "$recorded_hash" != "$source_hash" ]] \
    || [[ -z "$recorded_profile" ]] \
    || [[ "$recorded_profile" != "$encode_profile" ]]
}

trinket_asset_convert_aac() {
  local source_file="$1"
  local output_file="$2"
  local bitrate="$3"
  local label="$4"

  rm -f "$output_file"
  if ! afconvert "$source_file" "$output_file" -f m4af -d aac -b "$bitrate" --soundcheck-generate >/dev/null \
    || [[ ! -s "$output_file" ]]; then
    rm -f "$output_file"
    echo "Failed to produce a valid $label asset." >&2
    return 1
  fi
}

trinket_asset_prune_orphans() {
  local resources_dir="$1"
  local active_file="$2"
  local label="$3"
  local file_extension="$4"
  local file filename

  shopt -s nullglob
  for file in "$resources_dir"/*."$file_extension"; do
    [[ -f "$file" ]] || continue
    filename="$(basename "$file")"
    if ! grep -qx "$filename" "$active_file"; then
      echo "Pruning orphaned $label asset: $filename"
      rm -f "$file"
    fi
  done
  shopt -u nullglob
}

trinket_asset_sort_state() {
  local state_temp="$1"
  local state_file="$2"

  {
    head -n 2 "$state_temp"
    tail -n +3 "$state_temp" | LC_ALL=C sort -t$'\t' -k1,1
  } > "$state_temp.sorted"
  if [[ -f "$state_file" ]] && cmp -s "$state_temp.sorted" "$state_file"; then
    rm -f "$state_temp.sorted" "$state_temp"
  else
    mv -f "$state_temp.sorted" "$state_file"
    rm -f "$state_temp"
  fi
}

TRINKET_ASSET_STATE_FILE=""

trinket_asset_begin_state_lookup() {
  TRINKET_ASSET_STATE_FILE="$1"
}

trinket_asset_state_values() {
  local asset_name="$1"
  if [[ -z "$TRINKET_ASSET_STATE_FILE" || ! -f "$TRINKET_ASSET_STATE_FILE" ]]; then
    return 0
  fi
  awk -F$'\t' -v name="$asset_name" '$1 == name { print $2 "\t" $3; exit }' "$TRINKET_ASSET_STATE_FILE" 2>/dev/null || true
}

# Assigns recorded hash and optional encode profile for asset_name into the
# named caller variables (printf -v, bash 3.2-safe).
trinket_asset_read_recorded_state() {
  local _hash_var="$1"
  local _profile_var="$2"
  local _asset_name="$3"
  local _state_values _hash="" _profile=""
  _state_values="$(trinket_asset_state_values "$_asset_name")"
  if [[ -n "$_state_values" ]]; then
    _hash="${_state_values%%$'\t'*}"
    if [[ "$_state_values" == *$'\t'* ]]; then
      _profile="${_state_values#*$'\t'}"
    fi
  fi
  printf -v "$_hash_var" '%s' "$_hash"
  printf -v "$_profile_var" '%s' "$_profile"
}

# Writes unique Swift `id: "value"` tokens from the given files into dest.
trinket_asset_extract_swift_quoted_ids() {
  local dest="$1"
  shift
  if [[ $# -eq 0 ]]; then
    : > "$dest"
    return 0
  fi
  grep -h -oE 'id: "[^"]+"' "$@" 2>/dev/null \
    | sed 's/^id: "//;s/"$//' \
    | LC_ALL=C sort -u > "$dest" || true
}

trinket_asset_assert_unique() {
  local seen_file="$1"
  local label="$2"
  local value="$3"

  if [[ -f "$seen_file" ]] && grep -qxF "$value" "$seen_file"; then
    echo "Duplicate $label '$value'." >&2
    return 1
  fi
  printf '%s\n' "$value" >> "$seen_file"
}
