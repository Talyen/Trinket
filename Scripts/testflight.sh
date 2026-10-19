#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
doctor=false
for argument in "$@"; do
  case "$argument" in
    --help|-h|--dry-run)
      # Preview/help work before Ruby gems or credentials have been configured.
      exec env -u RUBYOPT -u RUBYLIB -u GEM_HOME -u GEM_PATH \
        -u BUNDLE_GEMFILE -u BUNDLE_PATH -u BUNDLE_FROZEN -u BUNDLE_IGNORE_CONFIG \
        /usr/bin/ruby Scripts/internal/testflight.rb "$@"
      ;;
    --doctor|--verify-symbols) doctor=true ;;
  esac
done
source Scripts/lib/output-retention.sh
source Scripts/lib/testflight-tools.sh
trinket_testflight_tools "$PWD" false
if [[ "$doctor" == true ]]; then
  exec "$TRINKET_BUNDLE" _4.0.15_ exec ruby Scripts/internal/testflight.rb "$@"
fi
source Scripts/lib/lock.sh
testflight_state_root() {
  PYTHONPATH=Scripts python3 - <<'PY'
from internal.cli import ROOT, legacy_runtime_owner, primary_worktree_root
import sys
owner = legacy_runtime_owner(ROOT, ('testflight/.deploy.lock',))
if owner is not None:
    sys.exit(f'Legacy checkout-local deployment lock preserved: {owner}. Finish that deployment before retrying.')
print(primary_worktree_root(ROOT) / '.DerivedData/testflight')
PY
}
shared_state="$(testflight_state_root)"
export TRINKET_TESTFLIGHT_STATE_ROOT="$shared_state"
trinket_dir_lock_acquire "$TRINKET_TESTFLIGHT_STATE_ROOT/.deploy.lock" 1
# Recheck after acquiring the shared lock: a legacy deployment may have started
# while this invocation was waiting. Never release another checkout's lock.
testflight_state_root >/dev/null
mkdir -p "$TRINKET_TESTFLIGHT_STATE_ROOT/commands"
export TRINKET_TESTFLIGHT_COMMAND_LOG
TRINKET_TESTFLIGHT_COMMAND_LOG="$(mktemp "$TRINKET_TESTFLIGHT_STATE_ROOT/commands/deploy.XXXXXX")"
trinket_output_retention_begin "$TRINKET_TESTFLIGHT_COMMAND_LOG"
chmod 600 "$TRINKET_TESTFLIGHT_COMMAND_LOG"
echo "Command log: $TRINKET_TESTFLIGHT_COMMAND_LOG"
# Keep the shell alive so its EXIT trap retains the deployment lock.
"$TRINKET_BUNDLE" _4.0.15_ exec ruby Scripts/internal/testflight.rb "$@" 2>&1 | tee "$TRINKET_TESTFLIGHT_COMMAND_LOG"
