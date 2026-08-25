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
