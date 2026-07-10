#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

INCLUDE_ASSETS=false
SKIP_XCODEGEN=false
GENERATION_LOCK_DIR="$PWD/.DerivedData/.generate.lock"
XCODEGEN_CACHE_PATH="$PWD/.DerivedData/XcodeGen.cache"

cleanup_generation_lock() {
  rm -rf "$GENERATION_LOCK_DIR"
}

acquire_generation_lock() {
  mkdir -p "$PWD/.DerivedData"

  while ! mkdir "$GENERATION_LOCK_DIR" 2>/dev/null; do
    local lock_pid=""
    if [[ -f "$GENERATION_LOCK_DIR/pid" ]]; then
      read -r lock_pid < "$GENERATION_LOCK_DIR/pid" || true
    fi

    if [[ "$lock_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
      rm -rf "$GENERATION_LOCK_DIR"
      continue
    fi

    sleep 1
  done

  printf '%s\n' "$$" > "$GENERATION_LOCK_DIR/pid"
  trap cleanup_generation_lock EXIT INT TERM
}

usage() {
  cat <<'EOF'
Usage: ./Scripts/generate.sh [options]

Runs manifest validation, content codegen, optional asset pipelines, and XcodeGen.

Options:
  --assets         Also run art, music, SFX, and cinematic asset pipelines (slow; for manifest edits)
  --skip-xcodegen  Skip XcodeGen (content/asset codegen only)
  -h, --help       Show this help

Prefer this script over individual generate-* subcommands.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --assets)
      INCLUDE_ASSETS=true
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

echo "=== Validating content manifests ==="
python3 Scripts/content_codegen.py validate

echo "=== Generating content catalogs ==="
python3 Scripts/content_codegen.py

if [[ "$INCLUDE_ASSETS" == true ]]; then
  echo "=== Preparing art assets ==="
  ./Scripts/prepare-art-assets.sh

  echo "=== Preparing music assets ==="
  ./Scripts/prepare-music-assets.sh

  echo "=== Preparing SFX catalog ==="
  ./Scripts/prepare-sfx-assets.sh

  echo "=== Preparing cinematic assets ==="
  ./Scripts/prepare-cinematic-assets.sh

  echo "=== Preparing app icon ==="
  ./Scripts/prepare-app-icon.sh
fi

if [[ "$SKIP_XCODEGEN" == false ]]; then
  echo "=== Generating Xcode project ==="
  # Prefer pinned .tools XcodeGen when present so local output matches CI.
  if [[ -x "$PWD/.tools/xcodegen" ]]; then
    export PATH="$PWD/.tools:$PATH"
  fi
  if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate \
      --use-cache \
      --cache-path "$XCODEGEN_CACHE_PATH"
  else
    echo "xcodegen not found; syncing legacy project sources into project.pbxproj"
    python3 Scripts/sync-xcodeproj-sources.py
  fi
fi

echo "=== Generate complete ==="
