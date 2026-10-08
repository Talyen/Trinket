#!/usr/bin/env bash
set -euo pipefail

# Diagnostic session identity shared by run-env.sh and tools.sh.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../lib/args.sh
source "$ROOT_DIR/Scripts/lib/args.sh"
# shellcheck source=../lib/args.sh
source "$ROOT_DIR/Scripts/lib/args.sh"

fail() {
  echo "test-lib-args.sh FAIL: $*" >&2
  exit 1
}

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
