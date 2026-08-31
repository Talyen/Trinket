#!/usr/bin/env bash
set -euo pipefail

# Stable collation for generated catalogs/assets (CI runners often use en_US.UTF-8,
# which reorders `# …` header lines under plain `sort`).
export LC_ALL=C
export LANG=C

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh

# Prefer Xcode's macOS SDK for SPM/`swift run` (AbilityInventoryDump). Newer macOS /
# CLT betas can leave a CommandLineTools SDK that mismatches Xcode's swiftc.
ensure_xcode_macos_sdk() {
  if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    local selected=""
    if command -v xcode-select >/dev/null 2>&1; then
      selected="$(xcode-select -p 2>/dev/null || true)"
    fi
    if [[ -n "$selected" && -d "$selected" ]]; then
      export DEVELOPER_DIR="$selected"
    elif [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
      export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    fi
  fi

  if ! command -v xcrun >/dev/null 2>&1; then
    echo "error: xcrun not found; install Xcode or set DEVELOPER_DIR." >&2
    return 1
  fi

  local sdk_path="${SDKROOT:-}"
  if [[ -z "$sdk_path" || ! -d "$sdk_path" ]]; then
    sdk_path="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
  fi
  if [[ -z "$sdk_path" || ! -d "$sdk_path" ]]; then
    echo "error: unable to resolve macOS SDK via xcrun --sdk macosx." >&2
    return 1
  fi
  if [[ "$sdk_path" == *"/CommandLineTools/"* ]]; then
    echo "error: macOS SDK resolved to Command Line Tools ($sdk_path)." >&2
    echo "Point xcode-select / DEVELOPER_DIR at Xcode.app and retry." >&2
    return 1
  fi
  export SDKROOT="$sdk_path"

  if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    local toolchain_bin="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin"
    local developer_bin="$DEVELOPER_DIR/usr/bin"
    if [[ -d "$toolchain_bin" ]]; then
      export PATH="$toolchain_bin:$developer_bin:$PATH"
    elif [[ -d "$developer_bin" ]]; then
      export PATH="$developer_bin:$PATH"
    fi
  fi
}

ensure_xcode_macos_sdk

INCLUDE_ASSETS=false
SKIP_XCODEGEN=false
FORCE_XCODEGEN=false

# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
trinket_run_env_init

GENERATION_LOCK_DIR="$TRINKET_GENERATE_LOCK_DIR"
XCODEGEN_CACHE_PATH="$TRINKET_XCODEGEN_CACHE_PATH"
LOCK_TIMEOUT_SECONDS="${TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS:-120}"

# Shared directory-lock primitive lives in Scripts/lib/lock.sh.
# shellcheck source=lib/lock.sh
source Scripts/lib/lock.sh

cleanup_generation_lock() {
  trinket_dir_lock_release "$GENERATION_LOCK_DIR" "$$"
}

acquire_generation_lock() {
  trinket_dir_lock_acquire "$GENERATION_LOCK_DIR" "$LOCK_TIMEOUT_SECONDS"
}

ensure_pinned_xcodegen_path() {
  # Prefer pinned .tools XcodeGen so local/agent output matches CI.
  trinket_prepend_pinned_tools

  if [[ "${TRINKET_REQUIRE_PINNED_TOOLS:-0}" == "1" ]]; then
    if [[ ! -x "$PWD/.tools/xcodegen" ]]; then
      echo "Pinned XcodeGen missing at .tools/xcodegen. Run ./Scripts/ensure-ci-tools.sh first." >&2
      return 1
    fi
    if [[ "$(command -v xcodegen)" != "$PWD/.tools/xcodegen" ]]; then
      echo "PATH must resolve xcodegen to .tools/xcodegen when TRINKET_REQUIRE_PINNED_TOOLS=1." >&2
      echo "Resolved: $(command -v xcodegen 2>/dev/null || echo missing)" >&2
      return 1
    fi
  fi
}

should_force_xcodegen() {
  if [[ "$FORCE_XCODEGEN" == true || "${TRINKET_FORCE_XCODEGEN:-0}" == "1" ]]; then
    return 0
  fi
  if [[ -f project.yml ]]; then
    if [[ ! -f "$XCODEGEN_CACHE_PATH" ]]; then
      return 0
    fi
    if [[ project.yml -nt "$XCODEGEN_CACHE_PATH" ]]; then
      return 0
    fi
    # Clock skew can make project.yml appear older than cache after a CI checkout;
    # fall back to content hash so stale project.yml still triggers regeneration.
    local current_hash=""
    local cached_hash=""
    if command -v shasum >/dev/null 2>&1; then
      current_hash="$(shasum -a 256 project.yml 2>/dev/null | awk '{print $1}')"
      cached_hash="$(cat "$XCODEGEN_CACHE_PATH.hash" 2>/dev/null || true)"
      if [[ -n "$current_hash" && "$current_hash" != "$cached_hash" ]]; then
        return 0
      fi
    fi
  fi
  return 1
}

usage() {
  cat <<'EOF'
Usage: ./Scripts/generate.sh [options]

Runs manifest validation, content codegen, optional asset pipelines, and XcodeGen.

Options:
  --assets          Also run art, music, SFX, cinematic, and app-icon asset pipelines (slow; for manifest edits)
  --force-xcodegen  Ignore XcodeGen cache and rewrite project.pbxproj (matches CI assert)
  --skip-xcodegen   Skip XcodeGen (content/asset codegen only)
  -h, --help        Show this help

Prefer this script over calling prepare-* asset scripts or content_codegen.py directly.

Env:
  TRINKET_FORCE_XCODEGEN=1       Same as --force-xcodegen
  TRINKET_REQUIRE_PINNED_TOOLS=1 Require .tools/xcodegen on PATH (agent push gate)
  FORCE_ASSET_REENCODE=1         Force art/SFX/music/cinematic/app-icon re-encode even when up to date
  DEVELOPER_DIR / SDKROOT        Optional overrides; otherwise Xcode (not CLT) is selected
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --assets)
      INCLUDE_ASSETS=true
      shift
      ;;
    --force-xcodegen)
      FORCE_XCODEGEN=true
      shift
      ;;
    --skip-xcodegen)
      SKIP_XCODEGEN=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

acquire_generation_lock

# content_codegen validates manifests before writing generated catalogs.
echo "=== Generating content catalogs ==="
python3 Scripts/content_codegen.py

if [[ "$INCLUDE_ASSETS" == true ]]; then
  echo "=== Preparing media assets ==="
  ./Scripts/prepare-assets.sh --kind all
fi

if [[ "$SKIP_XCODEGEN" == false ]]; then
  echo "=== Generating Xcode project ==="
  ensure_pinned_xcodegen_path
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen not found on PATH." >&2
    echo "Install the pinned toolchain with ./Scripts/ensure-ci-tools.sh (places .tools/xcodegen)." >&2
    echo "XcodeGen is required; the legacy sync-xcodeproj-sources.py fallback was removed." >&2
    exit 1
  fi
  if should_force_xcodegen; then
    echo "Forcing XcodeGen regenerate (cache ignored)."
    rm -f "$XCODEGEN_CACHE_PATH" "$XCODEGEN_CACHE_PATH.hash"
    mkdir -p "$(dirname "$XCODEGEN_CACHE_PATH")"
    xcodegen generate --cache-path "$XCODEGEN_CACHE_PATH"
    if command -v shasum >/dev/null 2>&1; then
      shasum -a 256 project.yml 2>/dev/null | awk '{print $1}' > "$XCODEGEN_CACHE_PATH.hash" || true
    fi
  else
    xcodegen generate \
      --use-cache \
      --cache-path "$XCODEGEN_CACHE_PATH"
    if command -v shasum >/dev/null 2>&1; then
      shasum -a 256 project.yml 2>/dev/null | awk '{print $1}' > "$XCODEGEN_CACHE_PATH.hash" || true
    fi
  fi
fi

echo "=== Generate complete ==="
