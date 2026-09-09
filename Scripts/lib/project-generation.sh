#!/usr/bin/env bash

# Both normal generation and the staged-project gate use this pinned entrypoint.
trinket_generate_project() (
  set -euo pipefail
  local tool_root="$1" project_root="$2" cache_dir
  source "$tool_root/Scripts/lib/tools.sh"
  trinket_require_pinned_tools "$tool_root"
  export LC_ALL=C LANG=C
  cache_dir="$(mktemp -d "${TMPDIR:-/tmp}/trinket-xcodegen.XXXXXX")"
  trap 'rm -rf "$cache_dir"' EXIT
  "$tool_root/.tools/xcodegen" generate --spec "$project_root/project.yml" \
    --cache-path "$cache_dir/cache"
  # The pinned XcodeGen silently drops `storeKitConfiguration`, which would
  # leave the app and UI tests without the test store. Pin the authored paths
  # into the generated schemes deterministically (idempotent no-op otherwise).
  python3 "$tool_root/Scripts/apply-scheme-storekit.py" --project-root "$project_root"
)

# Code inside synchronized source folders does not change project membership.
trinket_is_project_generation_input() {
  case "$1" in
    project.yml|*.xctestplan|Scripts/tool-versions.env|Scripts/generate.sh|\
    Scripts/apply-scheme-storekit.py|Scripts/ensure-ci-tools.sh|Scripts/lib/ci-tools.d/xcodegen.sh|\
    Scripts/lib/tools.sh|Scripts/lib/tool-install.sh|Scripts/lib/project-generation.sh|\
    Scripts/check-staged-project.sh|.githooks/pre-commit|\
    Trinket/Assets.xcassets/*|Trinket/AppIcon.icon/*|Trinket/PrivacyInfo.xcprivacy|\
    Trinket/Trinket.entitlements|StoreKit/*|Packages/*/Package.swift)
      return 0 ;;
    *) return 1 ;;
  esac
}
