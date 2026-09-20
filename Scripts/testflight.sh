#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
doctor=false
for argument in "$@"; do
  case "$argument" in
    --help|-h|--dry-run)
      # Preview/help work before Ruby gems or credentials have been configured.
      exec /usr/bin/ruby Scripts/internal/testflight.rb "$@"
      ;;
    --doctor) doctor=true ;;
  esac
done
source Scripts/lib/testflight-tools.sh
trinket_testflight_tools "$PWD" false
if [[ "$doctor" == true ]]; then
  exec "$TRINKET_BUNDLE" _4.0.15_ exec ruby Scripts/internal/testflight.rb "$@"
fi
source Scripts/lib/lock.sh
trinket_dir_lock_acquire "$PWD/.DerivedData/testflight/.deploy.lock" 1
mkdir -p .DerivedData/testflight/commands
export TRINKET_TESTFLIGHT_COMMAND_LOG
TRINKET_TESTFLIGHT_COMMAND_LOG="$(mktemp "$PWD/.DerivedData/testflight/commands/deploy.XXXXXX")"
chmod 600 "$TRINKET_TESTFLIGHT_COMMAND_LOG"
echo "Command log: $TRINKET_TESTFLIGHT_COMMAND_LOG"
# Keep the shell alive so its EXIT trap retains the deployment lock.
"$TRINKET_BUNDLE" _4.0.15_ exec ruby Scripts/internal/testflight.rb "$@" 2>&1 | tee "$TRINKET_TESTFLIGHT_COMMAND_LOG"
