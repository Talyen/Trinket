#!/usr/bin/env bash
set -euo pipefail

# Unit coverage for Scripts/lib/args.sh shared CLI helpers. Sourcing must be
# side-effect free and idempotent (run-env.sh and tools.sh both pull it in).

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../lib/args.sh
source "$ROOT_DIR/Scripts/lib/args.sh"
# shellcheck source=../lib/args.sh
source "$ROOT_DIR/Scripts/lib/args.sh"

fail() {
  echo "test-lib-args.sh FAIL: $*" >&2
  exit 1
}

# trinket_args_unknown prints to stderr and returns nonzero.
output="$(trinket_args_unknown "--bogus" "Usage: x" 2>&1)" && fail "unknown should return nonzero"
[[ "$output" == *"Unknown argument: --bogus"* ]] || fail "unknown message: $output"
[[ "$output" == *"Usage: x"* ]] || fail "unknown usage hint: $output"

# trinket_args_quiet_verbose normalizes both spellings.
QUIET=false
VERBOSE=false
trinket_args_quiet_verbose "--quiet" || fail "--quiet not handled"
[[ "$QUIET" == true ]] || fail "--quiet did not set QUIET"
trinket_args_quiet_verbose "--verbose" || fail "--verbose not handled"
[[ "$VERBOSE" == true && "$QUIET" == false ]] || fail "--verbose state wrong"
QUIET=false
VERBOSE=false
trinket_args_quiet_verbose "quiet" || fail "bare quiet not handled"
[[ "$QUIET" == true ]] || fail "bare quiet did not set QUIET"
trinket_args_quiet_verbose "--nope" && fail "--nope should not be handled"

# trinket_log_section emits the single greppable banner format.
[[ "$(trinket_log_section "Hello")" == "=== Hello ===" ]] || fail "log_section format"

# trinket_die exits 1 with message + usage on stderr.
output="$( (trinket_die "bad" "Usage: x") 2>&1 )" && fail "die should exit nonzero"
[[ "$output" == *"bad"* && "$output" == *"Usage: x"* ]] || fail "die output: $output"

# trinket_ensure_diagnostics_session mints once, preserves, honors RUN_ID.
unset TRINKET_DIAGNOSTICS_SESSION_ID
unset TRINKET_RUN_ID
trinket_ensure_diagnostics_session
first="${TRINKET_DIAGNOSTICS_SESSION_ID:-}"
[[ -n "$first" ]] || fail "session not minted"
trinket_ensure_diagnostics_session
[[ "$TRINKET_DIAGNOSTICS_SESSION_ID" == "$first" ]] || fail "session not stable"
TRINKET_DIAGNOSTICS_SESSION_ID="pinned"
trinket_ensure_diagnostics_session
[[ "$TRINKET_DIAGNOSTICS_SESSION_ID" == "pinned" ]] || fail "existing session overwritten"
unset TRINKET_DIAGNOSTICS_SESSION_ID
TRINKET_RUN_ID="run-123"
trinket_ensure_diagnostics_session
[[ "$TRINKET_DIAGNOSTICS_SESSION_ID" == "run-123" ]] || fail "RUN_ID not honored"
unset TRINKET_DIAGNOSTICS_SESSION_ID
unset TRINKET_RUN_ID

echo "test-lib-args.sh passed"
