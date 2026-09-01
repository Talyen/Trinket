#!/usr/bin/env bash

TRINKET_CHEAP_SLICES_CONFIG="${TRINKET_CHEAP_SLICES_CONFIG:-Scripts/config/cheap-slices.txt}"

trinket_cheap_slice_commands() {
  local config="${1:-$TRINKET_CHEAP_SLICES_CONFIG}"
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z "$line" ]] && continue
    printf '%s\n' "$line"
  done < "$config"
}

trinket_run_cheap_slices() {
  local cmd
  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    bash -c "$cmd" || return $?
  done < <(trinket_cheap_slice_commands)
}
