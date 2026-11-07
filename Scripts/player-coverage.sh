#!/usr/bin/env bash
set -euo pipefail
TRINKET_ENTRY_ARGS=("$@")
cd "$(dirname "$0")/.."
mode="${1:-}"
coverage_check="${2:-profiles}"
case "$mode:$coverage_check" in
  compact:profiles|tablet26:profiles|tablet:profiles|duo:profiles|compact:reward-return|tablet:reward-return|duo:rotation)
    selector="$(python3 Scripts/coverage_profiles.py definition --name "$mode")"
    IFS=$'\t' read -r TRINKET_SIM_DEVICE_TYPE TRINKET_SIM_OS_MAJOR <<< "$selector"
    export TRINKET_SIM_DEVICE_TYPE TRINKET_SIM_OS_MAJOR
    ;;
  soak:profiles) ;;
  *) echo 'Usage: ./Scripts/player-coverage.sh compact|tablet26|tablet|duo|soak [profiles|reward-return|rotation]' >&2; exit 2 ;;
esac
source Scripts/lib/verification-policy.sh
trinket_require_heavy_verification 'Player coverage profiles and soak' || exit $?
trinket_host_admit "$PWD/Scripts/player-coverage.sh" "${TRINKET_ENTRY_ARGS[@]+"${TRINKET_ENTRY_ARGS[@]}"}" || exit $?
export TRINKET_ISOLATE=1
source Scripts/run-env.sh
source Scripts/ensure-simulator.sh
trinket_run_env_init
trinket_sim_slot_ensure
trinket_run_env_install_self_clean
coverage_output="$DERIVED_DATA_PATH/PlayerCoverage/$mode-$coverage_check-$(date -u +%Y%m%dT%H%M%SZ)"
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
if [[ "$coverage_check" == reward-return || "$coverage_check" == rotation ]]; then
  # Apple's bootstatus already qualified the device. Let XCTest establish its
  # actual launch session; simctl getenv can hang on an otherwise booted iPad.
  export TRINKET_UI_PLAN=Profiles TRINKET_UI_SUCCESS_SCREENSHOTS=1
  if [[ "$coverage_check" == reward-return ]]; then
    export TRINKET_XCODE_WALL_TIMEOUT_SECONDS="${TRINKET_XCODE_WALL_TIMEOUT_SECONDS:-300}"
    ./Scripts/test.sh ui --no-build RewardReturnUITests/testClaimReturnsToCampaignAndOpensNextStage
  else
    TEST_RUNNER_TRINKET_DUO_PROFILE=1 \
      ./Scripts/test.sh ui --no-build DuoRotationUITests/testDuoRotationPreservesBattleAndCardPlay
  fi
elif [[ "$mode" != soak ]]; then
  python3 Scripts/coverage_profiles.py run --udid "$SIMULATOR_UDID" --output "$coverage_output" \
    --audit-policy "${TRINKET_COVERAGE_AUDIT_POLICY:-all}"
else
  mkdir -p "$coverage_output"
  export TRINKET_UI_PLAN=Soak
  coverage_status=0
  # Twenty production-timed battles plus foreground checks can exceed the generic 20-minute limit.
  TRINKET_XCODE_WALL_TIMEOUT_SECONDS="${TRINKET_XCODE_WALL_TIMEOUT_SECONDS:-2400}" \
    ./Scripts/test.sh ui --no-build RepeatedPlayUITests || coverage_status=1
  ./Scripts/test-package.sh --build-for-testing TrinketAppState
  career_products="$DERIVED_DATA_PATH/packages/TrinketAppState/Build/Products"
  # Ordinary careers share one worker; crash/recovery still crosses real processes.
  python3 Scripts/playthrough_sweep.py --products "$career_products" --destination "$SIMULATOR_DESTINATION" \
    --batch --coverage-portfolio --horizon 10 --full-access --output "$coverage_output/careers" || coverage_status=1
  python3 Scripts/playthrough_sweep.py --products "$career_products" --destination "$SIMULATOR_DESTINATION"     --seed 101 --crash-proof --full-access --output "$coverage_output/crash-recovery" || coverage_status=1
  exit "$coverage_status"
fi
