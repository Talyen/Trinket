#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

INCLUDE_ASSETS=false
SKIP_XCODEGEN=false

usage() {
  cat <<'EOF'
Usage: ./Scripts/generate.sh [options]

Runs manifest validation, content codegen, optional asset pipelines, and XcodeGen.

Options:
  --assets         Also run art and music asset pipelines (slow; for manifest edits)
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

  echo "=== Preparing app icon ==="
  ./Scripts/prepare-app-icon.sh
fi

if [[ "$SKIP_XCODEGEN" == false ]]; then
  echo "=== Generating Xcode project ==="
  if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate
  else
    echo "xcodegen not found; syncing test sources into project.pbxproj"
    python3 Scripts/sync-xcodeproj-sources.py
  fi
fi

echo "=== Generate complete ==="
