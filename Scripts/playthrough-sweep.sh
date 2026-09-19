#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for argument in "$@"; do
  if [[ "$argument" == "--help" || "$argument" == "-h" ]]; then
    playthrough_help="$(python3 Scripts/playthrough_sweep.py --help)"
    printf 'Usage:%s\n' "${playthrough_help#usage:}"
    exit 0
  fi
done
export TRINKET_ISOLATE=1
source Scripts/run-env.sh
source Scripts/ensure-simulator.sh
trinket_run_env_init
trinket_sim_slot_ensure
ensure_test_simulator_logged
trinket_run_env_install_self_clean
./Scripts/test-package.sh --build-for-testing TrinketAppState
python3 Scripts/playthrough_sweep.py --products "$DERIVED_DATA_PATH/packages/TrinketAppState/Build/Products" \
  --destination "$SIMULATOR_DESTINATION" "$@"
