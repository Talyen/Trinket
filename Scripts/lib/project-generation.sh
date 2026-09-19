#!/usr/bin/env bash

# Both normal generation and the staged-project gate use this pinned entrypoint.
trinket_generate_project() (
  set -euo pipefail
  local tool_root="$1" project_root="$2" cache_dir
  source "$tool_root/Scripts/lib/tools.sh"
  trinket_require_pinned_tools "$tool_root"
  export LC_ALL=C LANG=C
  # Subshell-local tracking: the parent shell's array and EXIT trap are
  # inherited, so reset before tracking or our EXIT would delete parent paths
  # (e.g. check-staged-project.sh's snapshot, still needed after we return).
  TRINKET_TEMP_TRACKED=()
  # shellcheck source=tempdir.sh
  source "$tool_root/Scripts/lib/tempdir.sh"
  trinket_mktemp_dir cache_dir trinket-xcodegen
  "$tool_root/.tools/xcodegen" generate --spec "$project_root/project.yml" \
    --cache-path "$cache_dir/cache"
  # The pinned XcodeGen silently drops `storeKitConfiguration`, which would
  # leave the app and UI tests without the test store. Pin the authored paths
  # into the generated schemes deterministically (idempotent no-op otherwise).
  python3 "$tool_root/Scripts/apply-scheme-storekit.py" --project-root "$project_root"
)

# Code inside synchronized source folders does not change project membership.
trinket_is_project_generation_input() {
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/build-inputs.env"
  local input
  for input in "${TRINKET_PROJECT_GENERATION_INPUTS[@]}"; do
    [[ "$1" == $input ]] && return 0
  done
  return 1
}
