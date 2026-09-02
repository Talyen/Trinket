#!/usr/bin/env bash
set -euo pipefail

# No-Xcode coverage for Scripts/run-env.sh isolation, agent sim slots, UI slots,
# Preview reclaim (empty / Shutdown-only / Booted), single-warm Booted
# enforcement, and generate lock timeout.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

REPO="$TMP_DIR/repo"
mkdir -p "$REPO/Scripts/lib"
cp "$ROOT_DIR/Scripts/run-env.sh" "$REPO/Scripts/run-env.sh"
cp "$ROOT_DIR/Scripts/simctl_json.py" "$REPO/Scripts/simctl_json.py"
cp "$ROOT_DIR/Scripts/lib/slots.sh" "$REPO/Scripts/lib/slots.sh"
cp "$ROOT_DIR/Scripts/lib/simctl.sh" "$REPO/Scripts/lib/simctl.sh"
cp "$ROOT_DIR/Scripts/lib/derived-data.sh" "$REPO/Scripts/lib/derived-data.sh"

FAKE_BIN="$TMP_DIR/bin"
FAKE_SHUTDOWN_LOG="$TMP_DIR/shutdown.log"
FAKE_ERASE_LOG="$TMP_DIR/erase.log"
FAKE_PREVIEW_LOG="$TMP_DIR/preview.log"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/xcrun" <<'FAKE_XCRUN'
#!/usr/bin/env bash
set -euo pipefail

# Preview device-set commands: list / shutdown / delete.
if [[ "$#" -ge 4 && "$1" == "simctl" && "$2" == "--set" && "$3" == "previews" ]]; then
  if [[ "$4" == "list" ]]; then
    # Banner mirrors real simctl --set previews list -j (JSON follows).
    echo "Using Previews Device Set: '/tmp/fake-previews'"
    case "${FAKE_PREVIEW_DEVICES:-empty}" in
      booted)
        cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"name":"Preview Phone","udid":"preview-1","state":"Booted"}]}}
JSON
        ;;
      shutdown)
        cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"name":"Preview Phone","udid":"preview-1","state":"Shutdown"}]}}
JSON
        ;;
      *)
        cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[]}}
JSON
        ;;
    esac
    exit 0
  fi
  printf '%s\n' "$4" >> "$FAKE_PREVIEW_LOG"
  exit 0
fi

if [[ "$#" -ge 3 && "$1" == "simctl" && "$2" == "spawn" ]]; then
  exit 0
fi

if [[ "$#" -ge 4 && "$1" == "simctl" && "$2" == "list" && "$3" == "devices" ]]; then
  # With FAKE_SHUTDOWN_COMPLETES=1, a udid recorded in the shutdown log reports
  # Shutdown — modeling real teardown instead of stalling shutdown waits.
  if [[ "${FAKE_SHUTDOWN_COMPLETES:-0}" == "1" && -n "${4:-}" && -s "$FAKE_SHUTDOWN_LOG" ]] \
    && grep -Fxq "$4" "$FAKE_SHUTDOWN_LOG"; then
    printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[{"name":"%s","udid":"%s","state":"Shutdown"}]}}\n' "$4" "$4"
    exit 0
  fi
  cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[{"name":"Trinket Agent 1","udid":"agent-1","state":"Booted"},{"name":"Trinket Run","udid":"ci-1","state":"Shutdown"}],"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"name":"Trinket Agent 2","udid":"agent-2","state":"Booted"},{"name":"Trinket Agent 3","udid":"agent-3","state":"Shutdown"},{"name":"iPhone 17 Pro","udid":"personal-device","state":"Booted"}]}}
JSON
  exit 0
fi

if [[ "$#" -ge 3 && "$1" == "simctl" && "$2" == "shutdown" ]]; then
  printf '%s\n' "$3" >> "$FAKE_SHUTDOWN_LOG"
  exit 0
fi

if [[ "$#" -ge 3 && "$1" == "simctl" && "$2" == "erase" ]]; then
  printf '%s\n' "$3" >> "$FAKE_ERASE_LOG"
  exit 0
fi

echo "unexpected xcrun invocation: $*" >&2
exit 1
FAKE_XCRUN
chmod +x "$FAKE_BIN/xcrun"

# Minimal generate.sh extract for lock timeout testing.
cat > "$REPO/Scripts/generate-lock-harness.sh" <<'HARNESS'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./Scripts/run-env.sh
trinket_run_env_init
GENERATION_LOCK_DIR="$TRINKET_GENERATE_LOCK_DIR"
LOCK_TIMEOUT_SECONDS="${TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS:-120}"
started_at=$SECONDS
while ! mkdir "$GENERATION_LOCK_DIR" 2>/dev/null; do
  lock_pid=""
  if [[ -f "$GENERATION_LOCK_DIR/pid" ]]; then
    read -r lock_pid < "$GENERATION_LOCK_DIR/pid" || true
  fi
  if [[ "$lock_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
    rm -rf "$GENERATION_LOCK_DIR"
    continue
  fi
  if (( SECONDS - started_at >= LOCK_TIMEOUT_SECONDS )); then
    echo "Generation lock timed out after ${LOCK_TIMEOUT_SECONDS}s." >&2
    exit 1
  fi
  sleep 1
done
echo "acquired"
rm -rf "$GENERATION_LOCK_DIR"
HARNESS
chmod +x "$REPO/Scripts/generate-lock-harness.sh"

# --- default shared tenant ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  unset TRINKET_ISOLATE TRINKET_RUN_ID DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT
  trinket_run_env_init
  [[ "$DERIVED_DATA_PATH" == "$PWD/.DerivedData" ]]
  [[ "$RESULTS_DIR" == "$PWD/.DerivedData/TestResults" ]]
  [[ "$TRINKET_SIMULATOR_NAME" == "Trinket Run" ]]
  [[ "${TRINKET_ISOLATE:-}" != "1" ]]
  [[ -z "${TRINKET_AGENT_SLOT:-}" ]]
' _ "$REPO"

# --- isolate acquires agent slot 1 ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_RUN_ID TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  export TRINKET_ISOLATE=1
  export TRINKET_RUN_ID="agent-test-1"
  trinket_run_env_init
  [[ "$TRINKET_AGENT_SLOT" == "1" ]]
  [[ "$DERIVED_DATA_PATH" == "$PWD/.DerivedData/runs/agent-1" ]]
  [[ "$RESULTS_DIR" == "$DERIVED_DATA_PATH/TestResults" ]]
  [[ "$TRINKET_SIMULATOR_NAME" == "Trinket Agent 1" ]]
  [[ "$TMPDIR" == "$DERIVED_DATA_PATH/tmp" ]]
  [[ -d "$TMPDIR" ]]
  [[ -f "$TRINKET_SIM_ACTIVE_DIR/1.slot" ]]
  trinket_sim_slot_release
' _ "$REPO"

# --- parent-held slot binds without second lock ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_SIM_SLOT_PATH
  export TRINKET_ISOLATE=1
  export TRINKET_RUN_ID="child-bind"
  export TRINKET_AGENT_SLOT=2
  trinket_run_env_init
  [[ "$TRINKET_AGENT_SLOT" == "2" ]]
  [[ "$DERIVED_DATA_PATH" == "$PWD/.DerivedData/runs/agent-2" ]]
  [[ "$TRINKET_SIMULATOR_NAME" == "Trinket Agent 2" ]]
  # No lock file created for parent-held bind
  [[ ! -e "${TRINKET_SIM_ACTIVE_DIR}/2.slot" ]]
' _ "$REPO"

# --- same-shell subshell cannot release its parent lease ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  export TRINKET_ISOLATE=1 TRINKET_RUN_ID="subshell-owner" TRINKET_MAX_AGENT_SIMS=1
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  trinket_run_env_init
  slot="$TRINKET_SIM_SLOT_PATH"
  ( trinket_sim_slot_release )
  [[ -e "$slot" ]]
  trinket_sim_slot_release
  [[ ! -e "$slot" ]]
' _ "$REPO"

# --- child UI trap cannot release the parent-held simulator slot ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  export TRINKET_ISOLATE=1
  export TRINKET_RUN_ID="parent-child-trap"
  export TRINKET_MAX_AGENT_SIMS=1
  export TRINKET_MAX_CONCURRENT_UI=2
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  trinket_run_env_init
  slot="$TRINKET_SIM_SLOT_PATH"
  bash -c '\''
    set -euo pipefail
    cd "$1"
    source Scripts/run-env.sh
    trinket_run_env_init
    trinket_ui_slot_acquire
  '\'' _ "$1"
  [[ -e "$slot" ]]
  trinket_sim_slot_release
  [[ ! -e "$slot" ]]
' _ "$REPO"

# --- explicit DERIVED_DATA_PATH + SIM name honored (skip pool) ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  export TRINKET_ISOLATE=1
  export TRINKET_RUN_ID="agent-test-2"
  export DERIVED_DATA_PATH="$1/custom-dd"
  export TRINKET_SIMULATOR_NAME="Custom Sim"
  unset RESULTS_DIR TRINKET_AGENT_SLOT
  trinket_run_env_init
  [[ "$DERIVED_DATA_PATH" == "$1/custom-dd" ]]
  [[ "$RESULTS_DIR" == "$1/custom-dd/TestResults" ]]
  [[ "$TRINKET_SIMULATOR_NAME" == "Custom Sim" ]]
  [[ -z "${TRINKET_AGENT_SLOT:-}" ]]
' _ "$REPO"

# --- agent sim slot fail-fast when pool full ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  export TRINKET_ISOLATE=1
  export TRINKET_RUN_ID="sim-cap"
  export TRINKET_MAX_AGENT_SIMS=2
  trinket_run_env_init
  mkdir -p "$TRINKET_SIM_ACTIVE_DIR"
  # Fill remaining slot with this live pid, then a third acquire must fail.
  # Slot 1 was taken by init; claim slot 2.
  printf "%s b %s\n" "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TRINKET_SIM_ACTIVE_DIR/2.slot"
  unset TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH DERIVED_DATA_PATH TRINKET_SIMULATOR_NAME
  if trinket_sim_slot_acquire; then
    echo "expected sim slot acquire to fail" >&2
    exit 1
  fi
  # Dead pid should be reaped
  printf "1 dead %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TRINKET_SIM_ACTIVE_DIR/dead.slot"
  trinket_sim_slot_reap
  [[ ! -e "$TRINKET_SIM_ACTIVE_DIR/dead.slot" ]]
  trinket_sim_slot_release
  rm -f "$TRINKET_SIM_ACTIVE_DIR/2.slot"
' _ "$REPO"

# --- UI slot fail-fast ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  export TRINKET_ISOLATE=1
  export TRINKET_RUN_ID="ui-cap"
  export TRINKET_MAX_CONCURRENT_UI=2
  export TRINKET_AGENT_SLOT=1
  unset DERIVED_DATA_PATH TRINKET_SIMULATOR_NAME
  trinket_run_env_init
  mkdir -p "$TRINKET_UI_ACTIVE_DIR"
  # Two live slots (this shell is alive)
  printf "%s a %s\n" "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TRINKET_UI_ACTIVE_DIR/one.slot"
  printf "%s b %s\n" "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TRINKET_UI_ACTIVE_DIR/two.slot"
  if trinket_ui_slot_acquire; then
    echo "expected UI slot acquire to fail" >&2
    exit 1
  fi
  # Dead pid should be reaped
  printf "1 dead %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TRINKET_UI_ACTIVE_DIR/dead.slot"
  trinket_ui_slot_reap
  [[ ! -e "$TRINKET_UI_ACTIVE_DIR/dead.slot" ]]
  rm -f "$TRINKET_UI_ACTIVE_DIR/one.slot" "$TRINKET_UI_ACTIVE_DIR/two.slot"
' _ "$REPO"

# --- empty Preview set: skip shutdown/delete ---
: > "$FAKE_PREVIEW_LOG"
: > "$FAKE_SHUTDOWN_LOG"
: > "$FAKE_ERASE_LOG"
bash -c '
  set -euo pipefail
  cd "$1"
  export PATH="$2:$PATH"
  export FAKE_PREVIEW_LOG="$3"
  export FAKE_SHUTDOWN_LOG="$4"
  export FAKE_ERASE_LOG="$5"
  export FAKE_PREVIEW_DEVICES=empty
  export TRINKET_CLEANUP_PREVIEW_SIMS=1
  export TRINKET_ISOLATE=1 TRINKET_RUN_ID="preview-empty"
  export TRINKET_CLEANUP_SINGLE_WARMED=0
  export TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE=0
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  unset TRINKET_SELF_CLEAN_OWNER
  source Scripts/run-env.sh
  trinket_run_env_init
  trinket_run_env_claim_self_clean_owner
  trinket_run_env_release_slots
  [[ ! -s "$FAKE_PREVIEW_LOG" ]]
' _ "$REPO" "$FAKE_BIN" "$FAKE_PREVIEW_LOG" "$FAKE_SHUTDOWN_LOG" "$FAKE_ERASE_LOG"

# --- Shutdown-only Preview devices: delete, skip shutdown ---
: > "$FAKE_PREVIEW_LOG"
: > "$FAKE_SHUTDOWN_LOG"
: > "$FAKE_ERASE_LOG"
bash -c '
  set -euo pipefail
  cd "$1"
  export PATH="$2:$PATH"
  export FAKE_PREVIEW_LOG="$3"
  export FAKE_SHUTDOWN_LOG="$4"
  export FAKE_ERASE_LOG="$5"
  export FAKE_PREVIEW_DEVICES=shutdown
  export TRINKET_CLEANUP_PREVIEW_SIMS=1
  export TRINKET_ISOLATE=1 TRINKET_RUN_ID="preview-shutdown-only"
  export TRINKET_CLEANUP_SINGLE_WARMED=0
  export TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE=0
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  unset TRINKET_SELF_CLEAN_OWNER
  source Scripts/run-env.sh
  trinket_run_env_init
  trinket_run_env_claim_self_clean_owner
  trinket_run_env_release_slots
  ! grep -q "shutdown" "$FAKE_PREVIEW_LOG"
  grep -Fx "delete" "$FAKE_PREVIEW_LOG"
' _ "$REPO" "$FAKE_BIN" "$FAKE_PREVIEW_LOG" "$FAKE_SHUTDOWN_LOG" "$FAKE_ERASE_LOG"

# --- Booted Preview devices: shutdown + delete ---
: > "$FAKE_PREVIEW_LOG"
: > "$FAKE_SHUTDOWN_LOG"
: > "$FAKE_ERASE_LOG"
bash -c '
  set -euo pipefail
  cd "$1"
  export PATH="$2:$PATH"
  export FAKE_PREVIEW_LOG="$3"
  export FAKE_SHUTDOWN_LOG="$4"
  export FAKE_ERASE_LOG="$5"
  export FAKE_PREVIEW_DEVICES=booted
  export TRINKET_CLEANUP_PREVIEW_SIMS=1
  export TRINKET_ISOLATE=1 TRINKET_RUN_ID="preview-reclaim"
  # Isolate Preview reclaim from single-warm / idle-pool side effects.
  export TRINKET_CLEANUP_SINGLE_WARMED=0
  export TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE=0
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  unset TRINKET_SELF_CLEAN_OWNER
  source Scripts/run-env.sh
  trinket_run_env_init
  trinket_run_env_claim_self_clean_owner
  trinket_run_env_release_slots
  grep -Fx "shutdown" "$FAKE_PREVIEW_LOG"
  grep -Fx "delete" "$FAKE_PREVIEW_LOG"
' _ "$REPO" "$FAKE_BIN" "$FAKE_PREVIEW_LOG" "$FAKE_SHUTDOWN_LOG" "$FAKE_ERASE_LOG"

# --- self-clean install runs Preview reclaim at start (Booted set) ---
: > "$FAKE_PREVIEW_LOG"
: > "$FAKE_SHUTDOWN_LOG"
: > "$FAKE_ERASE_LOG"
bash -c '
  set -euo pipefail
  cd "$1"
  export PATH="$2:$PATH"
  export FAKE_PREVIEW_LOG="$3"
  export FAKE_SHUTDOWN_LOG="$4"
  export FAKE_ERASE_LOG="$5"
  export FAKE_PREVIEW_DEVICES=booted
  export TRINKET_CLEANUP_PREVIEW_SIMS=1
  export TRINKET_ISOLATE=1 TRINKET_RUN_ID="start-hygiene"
  export TRINKET_CLEANUP_SINGLE_WARMED=0
  export TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE=0
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  unset TRINKET_SELF_CLEAN_OWNER
  source Scripts/run-env.sh
  trinket_run_env_init
  trinket_run_env_install_self_clean
  grep -Fx "shutdown" "$FAKE_PREVIEW_LOG"
  grep -Fx "delete" "$FAKE_PREVIEW_LOG"
  # Avoid EXIT double-clean noise; release lease only.
  unset TRINKET_SELF_CLEAN_OWNER
  trinket_sim_slot_release
' _ "$REPO" "$FAKE_BIN" "$FAKE_PREVIEW_LOG" "$FAKE_SHUTDOWN_LOG" "$FAKE_ERASE_LOG"

# --- child without self-clean ownership skips Preview reclaim ---
: > "$FAKE_PREVIEW_LOG"
: > "$FAKE_SHUTDOWN_LOG"
: > "$FAKE_ERASE_LOG"
bash -c '
  set -euo pipefail
  cd "$1"
  export PATH="$2:$PATH"
  export FAKE_PREVIEW_LOG="$3"
  export FAKE_SHUTDOWN_LOG="$4"
  export FAKE_ERASE_LOG="$5"
  export FAKE_PREVIEW_DEVICES=booted
  export TRINKET_CLEANUP_PREVIEW_SIMS=1
  export TRINKET_ISOLATE=1 TRINKET_RUN_ID="child-no-self-clean"
  export TRINKET_CLEANUP_SINGLE_WARMED=0
  export TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE=0
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  # Parent-owned token that does not match this process.
  export TRINKET_SELF_CLEAN_OWNER="parent-pid:0"
  source Scripts/run-env.sh
  trinket_run_env_init
  # Claiming again must not steal ownership from the parent token.
  trinket_run_env_claim_self_clean_owner
  [[ "$TRINKET_SELF_CLEAN_OWNER" == "parent-pid:0" ]]
  trinket_run_env_release_slots
  [[ ! -s "$FAKE_PREVIEW_LOG" ]]
' _ "$REPO" "$FAKE_BIN" "$FAKE_PREVIEW_LOG" "$FAKE_SHUTDOWN_LOG" "$FAKE_ERASE_LOG"

# --- single-warm: keep Agent 1, shut down excess Agent 2; never erase ---
: > "$FAKE_PREVIEW_LOG"
: > "$FAKE_SHUTDOWN_LOG"
: > "$FAKE_ERASE_LOG"
bash -c '
  set -euo pipefail
  cd "$1"
  export PATH="$2:$PATH"
  export FAKE_PREVIEW_LOG="$3"
  export FAKE_SHUTDOWN_LOG="$4"
  export FAKE_ERASE_LOG="$5"
  export TRINKET_ISOLATE=1 TRINKET_RUN_ID="single-warm"
  export TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE=0
  export FAKE_SHUTDOWN_COMPLETES=1
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  unset TRINKET_SELF_CLEAN_OWNER TRINKET_CLEANUP_SINGLE_WARMED
  source Scripts/run-env.sh
  trinket_run_env_init
  [[ "$TRINKET_SIMULATOR_NAME" == "Trinket Agent 1" ]]
  trinket_run_env_claim_self_clean_owner
  trinket_run_env_release_slots
  grep -Fx "agent-2" "$FAKE_SHUTDOWN_LOG"
  ! grep -q "agent-1" "$FAKE_SHUTDOWN_LOG"
  ! grep -q "personal-device" "$FAKE_SHUTDOWN_LOG"
  [[ ! -s "$FAKE_ERASE_LOG" ]]
' _ "$REPO" "$FAKE_BIN" "$FAKE_PREVIEW_LOG" "$FAKE_SHUTDOWN_LOG" "$FAKE_ERASE_LOG"

# --- held peer slot: keep active Agent 2, shut down Agent 1 ---
: > "$FAKE_PREVIEW_LOG"
: > "$FAKE_SHUTDOWN_LOG"
: > "$FAKE_ERASE_LOG"
bash -c '
  set -euo pipefail
  cd "$1"
  export PATH="$2:$PATH"
  export FAKE_PREVIEW_LOG="$3"
  export FAKE_SHUTDOWN_LOG="$4"
  export FAKE_ERASE_LOG="$5"
  export TRINKET_ISOLATE=1 TRINKET_RUN_ID="held-peer"
  export TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE=0
  export FAKE_SHUTDOWN_COMPLETES=1
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  unset TRINKET_SELF_CLEAN_OWNER
  source Scripts/run-env.sh
  trinket_run_env_init
  trinket_run_env_claim_self_clean_owner
  # Peer still holds slot 2 — prefer that keep-target over our released slot.
  printf "%s peer %s\n" "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TRINKET_SIM_ACTIVE_DIR/2.slot"
  trinket_run_env_release_slots
  grep -Fx "agent-1" "$FAKE_SHUTDOWN_LOG"
  ! grep -q "agent-2" "$FAKE_SHUTDOWN_LOG"
  [[ ! -s "$FAKE_ERASE_LOG" ]]
  rm -f "$TRINKET_SIM_ACTIVE_DIR/2.slot"
' _ "$REPO" "$FAKE_BIN" "$FAKE_PREVIEW_LOG" "$FAKE_SHUTDOWN_LOG" "$FAKE_ERASE_LOG"

# --- empty pool + single-warm off: keep Agents warm (no shutdown/erase) ---
: > "$FAKE_PREVIEW_LOG"
: > "$FAKE_SHUTDOWN_LOG"
: > "$FAKE_ERASE_LOG"
bash -c '
  set -euo pipefail
  cd "$1"
  export PATH="$2:$PATH"
  export FAKE_PREVIEW_LOG="$3"
  export FAKE_SHUTDOWN_LOG="$4"
  export FAKE_ERASE_LOG="$5"
  export TRINKET_ISOLATE=1 TRINKET_RUN_ID="idle-pool-warm"
  export TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE=0
  export TRINKET_CLEANUP_SINGLE_WARMED=0
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  unset TRINKET_SELF_CLEAN_OWNER
  source Scripts/run-env.sh
  trinket_run_env_init
  [[ "$TRINKET_MAX_AGENT_SIMS" == "1" ]]
  trinket_run_env_claim_self_clean_owner
  trinket_run_env_release_slots
  [[ ! -s "$FAKE_SHUTDOWN_LOG" ]]
  [[ ! -s "$FAKE_ERASE_LOG" ]]
' _ "$REPO" "$FAKE_BIN" "$FAKE_PREVIEW_LOG" "$FAKE_SHUTDOWN_LOG" "$FAKE_ERASE_LOG"

# --- non-isolate: keep Run Booted, shut down excess Agents; never erase ---
: > "$FAKE_PREVIEW_LOG"
: > "$FAKE_SHUTDOWN_LOG"
: > "$FAKE_ERASE_LOG"
bash -c '
  set -euo pipefail
  cd "$1"
  export PATH="$2:$PATH"
  export FAKE_PREVIEW_LOG="$3"
  export FAKE_SHUTDOWN_LOG="$4"
  export FAKE_ERASE_LOG="$5"
  unset TRINKET_ISOLATE TRINKET_RUN_ID TRINKET_AGENT_SLOT
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_SIM_SLOT_PATH
  unset TRINKET_SELF_CLEAN_OWNER TRINKET_CLEANUP_SINGLE_WARMED
  export TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE=0
  export FAKE_SHUTDOWN_COMPLETES=1
  source Scripts/run-env.sh
  trinket_run_env_init
  [[ "$TRINKET_SIMULATOR_NAME" == "Trinket Run" ]]
  trinket_run_env_claim_self_clean_owner
  trinket_run_env_release_slots
  # Fake list has Run Shutdown + Agents Booted — keep target Run is not Booted, so
  # first Booted managed (agent-1) is kept and agent-2 is shut down.
  grep -Fx "agent-2" "$FAKE_SHUTDOWN_LOG"
  ! grep -q "agent-1" "$FAKE_SHUTDOWN_LOG"
  [[ ! -s "$FAKE_ERASE_LOG" ]]
' _ "$REPO" "$FAKE_BIN" "$FAKE_PREVIEW_LOG" "$FAKE_SHUTDOWN_LOG" "$FAKE_ERASE_LOG"

# --- age-prune drops old TestResults entries, keeps Build ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  unset TRINKET_ISOLATE TRINKET_RUN_ID TRINKET_AGENT_SLOT
  trinket_run_env_init
  mkdir -p "$TRINKET_SHARED_DERIVED_DATA/TestResults/old-bundle"
  mkdir -p "$TRINKET_SHARED_DERIVED_DATA/TestResults/fresh-bundle"
  mkdir -p "$TRINKET_SHARED_DERIVED_DATA/Build/Products"
  touch "$TRINKET_SHARED_DERIVED_DATA/Build/Products/keep"
  # mtime older than default 3d
  touch -t 202001010101 "$TRINKET_SHARED_DERIVED_DATA/TestResults/old-bundle"
  touch "$TRINKET_SHARED_DERIVED_DATA/TestResults/fresh-bundle"
  trinket_derived_data_age_prune
  [[ ! -e "$TRINKET_SHARED_DERIVED_DATA/TestResults/old-bundle" ]]
  [[ -d "$TRINKET_SHARED_DERIVED_DATA/TestResults/fresh-bundle" ]]
  [[ -f "$TRINKET_SHARED_DERIVED_DATA/Build/Products/keep" ]]
' _ "$REPO"

# --- age-prune drops aged package-local .build / .DerivedData ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  unset TRINKET_ISOLATE TRINKET_RUN_ID TRINKET_AGENT_SLOT
  trinket_run_env_init
  mkdir -p "$1/Packages/DemoPkg/.build/objects"
  mkdir -p "$1/Packages/DemoPkg/.DerivedData/ModuleCache"
  mkdir -p "$1/Packages/DemoPkgFresh/.build/objects"
  touch "$1/Packages/DemoPkg/.build/objects/old"
  touch "$1/Packages/DemoPkgFresh/.build/objects/fresh"
  touch -t 202001010101 "$1/Packages/DemoPkg/.build"
  touch -t 202001010101 "$1/Packages/DemoPkg/.DerivedData"
  touch "$1/Packages/DemoPkgFresh/.build"
  trinket_derived_data_age_prune
  [[ ! -e "$1/Packages/DemoPkg/.build" ]]
  [[ ! -e "$1/Packages/DemoPkg/.DerivedData" ]]
  [[ -d "$1/Packages/DemoPkgFresh/.build" ]]
' _ "$REPO"

# --- generate lock timeout ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  # Shared tenant — no sim slot needed
  unset TRINKET_ISOLATE TRINKET_RUN_ID TRINKET_AGENT_SLOT
  trinket_run_env_init
  mkdir -p "$TRINKET_GENERATE_LOCK_DIR"
  # Holder is this live shell — timeout should fire.
  printf "%s\n" "$$" > "$TRINKET_GENERATE_LOCK_DIR/pid"
  if TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS=2 ./Scripts/generate-lock-harness.sh; then
    echo "expected generate lock timeout" >&2
    exit 1
  fi
  rm -rf "$TRINKET_GENERATE_LOCK_DIR"
' _ "$REPO"

# --- shutdown wait honors TRINKET_SIMULATOR_SHUTDOWN_TIMEOUT_SECONDS ---
bash -c '
  set -euo pipefail
  cd "$1"
  export PATH="$2:$PATH"
  export FAKE_SHUTDOWN_COMPLETES=0
  source Scripts/run-env.sh
  # Fake device list keeps agent-1 Booted forever, so the wait must hit its cap.
  started=$SECONDS
  warning="$(TRINKET_SIMULATOR_SHUTDOWN_TIMEOUT_SECONDS=1 trinket_sim_shutdown_wait agent-1 2>&1)"
  elapsed=$(( SECONDS - started ))
  (( elapsed >= 1 ))
  (( elapsed <= 3 ))
  [[ "$warning" == *"did not reach Shutdown within 1s"* ]]
  # A device that reports Shutdown (or an unknown udid) returns without waiting.
  TRINKET_SIMULATOR_SHUTDOWN_TIMEOUT_SECONDS=10 trinket_sim_shutdown_wait ci-1 >/dev/null
  TRINKET_SIMULATOR_SHUTDOWN_TIMEOUT_SECONDS=0 trinket_sim_shutdown_wait agent-1 >/dev/null
' _ "$REPO" "$FAKE_BIN"

# --- leases are reaped when stale by age, even with a live pid (pid reuse) ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  export TRINKET_ISOLATE=1 TRINKET_RUN_ID="stale-age"
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SIM_SLOT_PATH
  trinket_run_env_init
  printf "%s old %s\n" "$$" "2020-01-01T00:00:00Z" > "$TRINKET_SIM_ACTIVE_DIR/stale.slot"
  trinket_sim_slot_reap
  [[ ! -e "$TRINKET_SIM_ACTIVE_DIR/stale.slot" ]]
  printf "%s fresh %s\n" "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TRINKET_SIM_ACTIVE_DIR/fresh.slot"
  trinket_sim_slot_reap
  [[ -e "$TRINKET_SIM_ACTIVE_DIR/fresh.slot" ]]
  rm -f "$TRINKET_SIM_ACTIVE_DIR/fresh.slot"
  trinket_sim_slot_release
' _ "$REPO"

# --- shared-device lease: contention fails fast; release frees the device ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  unset TRINKET_ISOLATE TRINKET_RUN_ID DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT TRINKET_SHARED_SIM_SLOT_PATH
  trinket_run_env_init
  trinket_shared_sim_lease_acquire
  [[ -e "$TRINKET_SIM_ACTIVE_DIR/run.slot" ]]
  if bash -c "
    set -euo pipefail
    cd \"\$1\"
    source Scripts/run-env.sh
    unset TRINKET_ISOLATE TRINKET_RUN_ID TRINKET_SHARED_SIM_SLOT_PATH DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME
    trinket_run_env_init >/dev/null
    trinket_shared_sim_lease_acquire
  " _ "$1"; then
    echo "expected shared lease contention failure" >&2
    exit 1
  fi
  # The peer release must not clear our own live lease.
  [[ -e "$TRINKET_SIM_ACTIVE_DIR/run.slot" ]]
  trinket_shared_sim_lease_release
  [[ ! -e "$TRINKET_SIM_ACTIVE_DIR/run.slot" ]]
  # A stale lease is reclaimed automatically on the next acquire.
  printf "%s stale %s\n" "$$" "2020-01-01T00:00:00Z" > "$TRINKET_SIM_ACTIVE_DIR/run.slot"
  trinket_shared_sim_lease_acquire
  read -r holder _ < "$TRINKET_SIM_ACTIVE_DIR/run.slot"
  [[ "$holder" == "$$" ]]
  trinket_shared_sim_lease_release
' _ "$REPO"

echo "run-env isolation tests passed"
