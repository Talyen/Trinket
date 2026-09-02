#!/usr/bin/env bash
# Shared CLI argument helpers — single source for the quiet/verbose/unknown
# handling previously copy-pasted across test/build/handoff/generate wrappers.
# Sourcing this file has no side effects; callers keep their own flag loops
# and invoke these helpers for the shared cases.

# Print an unknown-option error with usage hint and exit 1.
# Usage: trinket_args_unknown "<option>" ["<usage>"]
trinket_args_unknown() {
  local option="${1:-}"
  local usage="${2:-}"
  echo "Unknown argument: $option" >&2
  if [[ -n "$usage" ]]; then
    echo "$usage" >&2
  fi
  return 1
}

# Normalize quiet/verbose pairs: --quiet sets QUIET=true, --verbose sets
# VERBOSE=true and QUIET=false. Returns 0 when $1 was handled.
# Usage: if trinket_args_quiet_verbose "$1"; then shift; continue; fi
trinket_args_quiet_verbose() {
  case "${1:-}" in
    --quiet|quiet)
      QUIET=true
      return 0
      ;;
    --verbose|verbose)
      VERBOSE=true
      QUIET=false
      return 0
      ;;
  esac
  return 1
}
