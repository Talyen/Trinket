#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

source_dir="Raw Assets/App Icon/Trinket-Icon-v1 Exports"
target_dir="Trinket/Assets.xcassets/AppIcon.appiconset"

if [[ ! -d "$source_dir" ]]; then
  echo "Missing source directory: $source_dir" >&2
  exit 1
fi

echo "=== Preparing app icon ==="

sources=(
  "Trinket-Icon-v1-iOS-Default-1024x1024@1x.png"
  "Trinket-Icon-v1-iOS-Dark-1024x1024@1x.png"
)
destinations=("AppIcon-Default.png" "AppIcon-Dark.png")

for index in "${!sources[@]}"; do
  src="${sources[$index]}"
  dst="${destinations[$index]}"
  if [[ ! -f "$source_dir/$src" ]]; then
    echo "  WARNING: Missing source $src, skipping" >&2
    continue
  fi
  cp "$source_dir/$src" "$target_dir/$dst"
  echo "  Installed $dst"
done

echo "=== App icon ready ==="
