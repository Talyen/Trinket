#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-}"
case "$mode" in
  compact|tablet)
    selector="$(python3 Scripts/coverage_profiles.py definition --name "$mode")"
    IFS=$'\t' read -r TRINKET_SIM_DEVICE_TYPE TRINKET_SIM_OS_MAJOR <<< "$selector"
    export TRINKET_SIM_DEVICE_TYPE TRINKET_SIM_OS_MAJOR
    ;;
  soak) ;;
  *) echo 'Usage: ./Scripts/player-coverage.sh compact|tablet|soak' >&2; exit 2 ;;
esac
source Scripts/lib/verification-policy.sh
trinket_require_heavy_verification 'Player coverage profiles and soak' || exit $?
export TRINKET_ISOLATE=1
source Scripts/run-env.sh
source Scripts/ensure-simulator.sh
trinket_run_env_init
trinket_sim_slot_ensure
trinket_run_env_install_self_clean
coverage_output="$DERIVED_DATA_PATH/PlayerCoverage/$mode-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$(dirname "$coverage_output")"
if ! ensure_test_simulator_logged; then
  mkdir -p "$coverage_output"
  printf '{"status":"unavailable","profile":"%s","reason":"simulator prerequisite failed"}\n' "$mode" > "$coverage_output/prerequisite.json"
  exit 2
fi
# One build per architecture, reused across all three settings profiles.
if [[ "${TRINKET_COVERAGE_NO_BUILD:-0}" != 1 ]]; then
  ./Scripts/build-for-testing.sh --app-only
fi
export SKIP_GENERATE=1
if [[ "$mode" != soak ]]; then
  python3 Scripts/coverage_profiles.py run --udid "$SIMULATOR_UDID" --output "$coverage_output"
else
  mkdir -p "$coverage_output"
  export TRINKET_UI_PLAN=Soak
  coverage_status=0
  ./Scripts/test.sh ui --no-build RepeatedPlayUITests || coverage_status=1
  ./Scripts/test-package.sh --build-for-testing TrinketAppState
  career_products="$DERIVED_DATA_PATH/packages/TrinketAppState/Build/Products"
  for career_mode in campaign contracts labyrinth spires; do
    for seed in 101 102 103 104 105; do
      policy=setupAware-v1
      (( seed % 2 == 0 )) && policy=random-v1
      career_status=0
      python3 Scripts/playthrough_sweep.py --products "$career_products" --destination "$SIMULATOR_DESTINATION" --seed "$seed" --scenarios 1 --horizon 10 --full-access \
        --mode "$career_mode" --policy "$policy" --output "$coverage_output/$career_mode-$seed" || career_status=$?
      printf '%s\t%s\t%s\n' "$career_mode" "$seed" "$career_status" >> "$coverage_output/careers.tsv"
      (( career_status == 0 )) || coverage_status=1
    done
  done
  python3 Scripts/playthrough_sweep.py --products "$career_products" --destination "$SIMULATOR_DESTINATION"     --seed 101 --crash-proof --full-access --output "$coverage_output/crash-recovery" || coverage_status=1
  exit "$coverage_status"
fi
