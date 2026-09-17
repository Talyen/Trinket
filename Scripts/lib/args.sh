#!/usr/bin/env bash
# Shared CLI argument helpers — single source for the quiet/verbose/unknown
# handling previously copy-pasted across test/build/handoff/generate wrappers.
# Sourcing this file has no side effects; callers keep their own flag loops
# and invoke these helpers for the shared cases. Safe to source twice
# (run-env.sh and tools.sh both pull it in for their consumers).
[[ -n "${_TRINKET_ARGS_SH_LOADED:-}" ]] && return 0
_TRINKET_ARGS_SH_LOADED=1

# Print "<message>" to stderr and exit 1. For usage errors with a hint.
# Usage: trinket_die "message" ["usage hint"]
trinket_die() {
  local message="${1:-}"
  local usage="${2:-}"
  [[ -n "$message" ]] && echo "$message" >&2
  [[ -n "$usage" ]] && echo "$usage" >&2
  exit 1
}

# Print a "=== section ===" banner. Single source for gate log structure
# so section headers stay greppable across handoff/ci-gate/test scripts.
# Usage: trinket_log_section "Generating Xcode project"
trinket_log_section() {
  echo "=== $1 ==="
}

# Mint TRINKET_DIAGNOSTICS_SESSION_ID when the caller has none. Honors an
# existing TRINKET_RUN_ID so isolated runs keep one session per run.
# Usage: trinket_ensure_diagnostics_session
trinket_ensure_diagnostics_session() {
  if [[ -n "${TRINKET_DIAGNOSTICS_SESSION_ID:-}" ]]; then
    return 0
  fi
  if [[ -n "${TRINKET_RUN_ID:-}" ]]; then
    TRINKET_DIAGNOSTICS_SESSION_ID="$TRINKET_RUN_ID"
  else
    TRINKET_DIAGNOSTICS_SESSION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM:-0}"
  fi
  export TRINKET_DIAGNOSTICS_SESSION_ID
}

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
