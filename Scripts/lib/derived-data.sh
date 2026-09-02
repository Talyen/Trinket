#!/usr/bin/env bash

trinket_prune_rebuildable_derived_data() {
  local target="$1"
  rm -rf \
    "$target/Build/Intermediates.noindex" \
    "$target/Build/ProfileData" \
    "$target/Index.noindex" \
    "$target/Index" \
    "$target/SymbolCache" \
    "$target/SDKStatCaches.noindex" \
    "$target/CompilationCache.noindex" \
    "$target/Logs" \
    2>/dev/null || true
}

trinket_derived_data_age_prune() {
  [[ "${TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE:-1}" == "1" ]] || return 0
  local shared_root="${TRINKET_SHARED_DERIVED_DATA:-$(trinket_run_env_shared_root)}"
  local max_age_days="${TRINKET_RUN_MAX_AGE_DAYS:-3}"
  local repo_root
  repo_root="$(trinket_run_env_repo_root)"

  if [[ -d "$shared_root" ]]; then
    if [[ -d "$shared_root/runs" ]]; then
      find "$shared_root/runs" -mindepth 1 -maxdepth 1 -type d \
        ! -name 'agent-*' \
        -mtime "+${max_age_days}" \
        -exec rm -rf {} + 2>/dev/null || true
    fi

    local -a roots=("$shared_root")
    local agent_dir
    if [[ -d "$shared_root/runs" ]]; then
      for agent_dir in "$shared_root/runs"/agent-*; do
        [[ -d "$agent_dir" ]] || continue
        roots+=("$agent_dir")
      done
    fi
    local root name
    for root in "${roots[@]}"; do
      for name in TestResults PerformanceResults Logs; do
        if [[ -d "$root/$name" ]]; then
          find "$root/$name" -mindepth 1 -maxdepth 1 -mtime "+${max_age_days}" \
            -exec rm -rf {} + 2>/dev/null || true
        fi
      done
    done
  fi

  local package_dir
  if [[ -d "$repo_root/BalanceSweepReports" ]]; then
    find "$repo_root/BalanceSweepReports" -mindepth 1 -maxdepth 1 -mtime "+${max_age_days}" \
      -exec rm -rf {} + 2>/dev/null || true
  fi
  if [[ -d "$repo_root/Packages" ]]; then
    if [[ -d "$repo_root/Packages/.DerivedData" ]]; then
      rm -rf "$repo_root/Packages/.DerivedData" 2>/dev/null || true
    fi
    for package_dir in "$repo_root/Packages"/*; do
      [[ -d "$package_dir" ]] || continue
      for name in .build .DerivedData; do
        if [[ -d "$package_dir/$name" ]]; then
          find "$package_dir/$name" -mindepth 0 -maxdepth 0 -mtime "+${max_age_days}" \
            -exec rm -rf {} + 2>/dev/null || true
        fi
      done
    done
  fi
}
