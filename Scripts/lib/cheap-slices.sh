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
  local config="${TRINKET_CHEAP_SLICES_CONFIG:-Scripts/config/cheap-slices.txt}"
  [[ -f "$config" ]] || { echo "Cheap-slice registry is missing: $config" >&2; return 1; }
  local ran_any=false line cmd flags
  while IFS= read -r line || [[ -n "$line" ]]; do
    flags=""
    case "$line" in
      *"#"*) flags="${line#*#}" ;;
    esac
    cmd="${line%%#*}"
    cmd="$(printf '%s' "$cmd" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z "$cmd" ]] && continue
    if [[ "$after_style" == true ]] && { [[ "$cmd" == ./Scripts/check-api-bans.sh ]] || [[ "$flags" == *skip-when-style-checked* ]]; }; then
      continue
    fi
    ran_any=true
    if [[ "$dry_run" == true ]]; then
      printf '%s\n' "$cmd"
    else
      bash -c "$cmd" || return $?
    fi
  done < "$config"
  [[ "$ran_any" == true ]] || { echo "Cheap-slice registry is empty." >&2; return 1; }
}

# trinket_run_gate_slices [--style-checked] [--dry-run]
#
# Single entry point for handoff.sh and ci-gate.sh so execution and --dry-run
# preview share the style derivation instead of each restating it.
trinket_run_gate_slices() {
  local style_checked=false dry_run=false option
  for option in "$@"; do
    case "$option" in
      --style-checked) style_checked=true ;;
      --dry-run) dry_run=true ;;
      *) echo "Unknown gate-slice option: $option" >&2; return 2 ;;
    esac
  done
  local -a slice_args=()
  [[ "$style_checked" == true ]] && slice_args+=(--after-style)
  [[ "$dry_run" == true ]] && slice_args+=(--dry-run)
  trinket_run_cheap_slices ${slice_args[@]+"${slice_args[@]}"}
}
