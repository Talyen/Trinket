#!/usr/bin/env bash

trinket_prune_rebuildable_derived_data() {
  local target="$1"
  rm -rf \
    "$target/Build/ProfileData" \
    "$target/Index.noindex" \
    "$target/Index" \
    "$target/SymbolCache" \
    "$target/Logs" \
    2>/dev/null || true
}

trinket_derived_data_age_prune() {
  [[ "${TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE:-1}" == "1" ]] || return 0
  python3 "$(trinket_run_env_repo_root)/Scripts/cleanup-outputs.py" --apply >/dev/null
}
