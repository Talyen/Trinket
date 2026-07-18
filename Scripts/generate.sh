#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

INCLUDE_ASSETS=false
SKIP_XCODEGEN=false

# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
trinket_run_env_init

GENERATION_LOCK_DIR="$TRINKET_GENERATE_LOCK_DIR"
XCODEGEN_CACHE_PATH="$TRINKET_XCODEGEN_CACHE_PATH"
LOCK_TIMEOUT_SECONDS="${TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS:-120}"

cleanup_generation_lock() {
  rm -rf "$GENERATION_LOCK_DIR"
}

acquire_generation_lock() {
  mkdir -p "$(dirname "$GENERATION_LOCK_DIR")"
  local started_at=$SECONDS
  local lock_pid=""

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
      if [[ "$lock_pid" =~ ^[0-9]+$ ]]; then
        echo "Held by pid $lock_pid. Do not kill foreign generate/xcodebuild processes." >&2
      else
        echo "Lock directory exists at $GENERATION_LOCK_DIR without a live pid." >&2
      fi
      echo "Retry after the peer finishes, or continue in a worktree (./Scripts/agent-worktree.sh)." >&2
      return 1
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

# content_codegen validates manifests before writing generated catalogs.
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
