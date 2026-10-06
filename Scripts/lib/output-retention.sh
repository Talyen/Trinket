#!/usr/bin/env bash
# Owner-aware output lifecycle; custom destinations outside known roots stay caller-owned.

source Scripts/lib/lock.sh

trinket_output_retention_begin() {
  local path="$1" comparison="${2:-false}" pid="${BASHPID:-$$}" cleanup
  [[ "${TRINKET_OUTPUT_RETENTION_READY:-0}" == 1 ]] || python3 Scripts/cleanup-outputs.py --apply >/dev/null || return $?
  export TRINKET_OUTPUT_RETENTION_READY=1
  if python3 Scripts/cleanup-outputs.py --begin "$path" --owner-pid "$pid"; then
    printf -v cleanup 'trinket_output_retention_finish %q %q %q "$?"' "$path" "$pid" "$comparison"
    trinket_dir_lock_chain_trap "$cleanup"
  else
    local status=$?
    if [[ "$status" == 3 ]]; then
      : # Explicit custom destinations stay caller-owned.
    else
      return "$status"
    fi
  fi
}

trinket_output_retention_finish() {
  local path="$1" pid="$2" comparison="$3" status="$4"
  local flags=()
  [[ "${TRINKET_CLEANUP_TEST_ARTIFACTS:-1}" == 0 ]] && comparison=true
  [[ "$comparison" == true ]] && flags+=(--comparison)
  if [[ "${TRINKET_KEEP_REPORTS:-0}" == 1 ]]; then
    python3 Scripts/cleanup-outputs.py --keep "$path" >/dev/null || true
  fi
  python3 Scripts/cleanup-outputs.py --finish "$path" --owner-pid "$pid" --status "$status" "${flags[@]+"${flags[@]}"}" || true
}
