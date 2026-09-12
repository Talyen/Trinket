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
  local dry_run=false after_style=false option
  for option in "$@"; do
    case "$option" in
      --dry-run) dry_run=true ;;
      --after-style) after_style=true ;;
      *) echo "Unknown cheap-slice option: $option" >&2; return 2 ;;
    esac
  done
  local commands
  commands="$(trinket_cheap_slice_commands)" || return $?
  [[ -n "$commands" ]] || { echo "Cheap-slice registry is empty." >&2; return 1; }
  local cmd
  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    [[ "$after_style" == true && "$cmd" == ./Scripts/check-api-bans.sh ]] && continue
    if [[ "$dry_run" == true ]]; then
      printf '%s\n' "$cmd"
    else
      bash -c "$cmd" || return $?
    fi
  done <<< "$commands"
}
