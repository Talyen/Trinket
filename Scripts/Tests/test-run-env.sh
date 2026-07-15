#!/usr/bin/env bash
set -euo pipefail

# No-Xcode coverage for Scripts/run-env.sh isolation, agent sim slots, UI slots,
# and generate lock timeout.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

REPO="$TMP_DIR/repo"
mkdir -p "$REPO/Scripts"
cp "$ROOT_DIR/Scripts/run-env.sh" "$REPO/Scripts/run-env.sh"
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
  [[ "$TRINKET_SIMULATOR_NAME" == "Trinket CI" ]]
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

# --- dry-run preview skips locking ---
bash -c '
  set -euo pipefail
  cd "$1"
  source Scripts/run-env.sh
  unset DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT
  export TRINKET_ISOLATE=1
  export TRINKET_RUN_ID="preview"
  export TRINKET_SIM_SLOT_SKIP_ACQUIRE=1
  trinket_run_env_init
  [[ "$TRINKET_SIMULATOR_NAME" == "Trinket Agent (pool)" ]]
  [[ "$DERIVED_DATA_PATH" == "$PWD/.DerivedData/runs/agent-preview" ]]
  [[ -z "${TRINKET_AGENT_SLOT:-}" ]]
  [[ ! -d "$PWD/.DerivedData/.active-sim" ]] || [[ -z "$(ls -A "$PWD/.DerivedData/.active-sim" 2>/dev/null || true)" ]]
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

echo "run-env isolation tests passed"
