#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -gt 0 ]]; then
  echo "Usage: ./Scripts/setup-testflight.sh"
  echo "Install locked local TestFlight tooling; does not configure credentials or upload."
  [[ "$1" == --help || "$1" == -h ]] && exit 0
  exit 2
fi
source Scripts/lib/testflight-tools.sh
source Scripts/lib/lock.sh
trinket_dir_lock_acquire "$PWD/.tools/.testflight-setup.lock" 120
trinket_testflight_tools "$PWD" true
echo "TestFlight tooling ready. Configure the local API key as described in Docs/Platform/Release.md, then run ./Scripts/testflight.sh --doctor."
