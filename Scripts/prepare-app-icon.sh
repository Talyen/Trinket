#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

source_dir="Raw Assets/App Icon/Trinket-Icon-v1 Exports"
target_dir="Trinket/Assets.xcassets/AppIcon.appiconset"

if [[ ! -d "$source_dir" ]]; then
  echo "Missing source directory: $source_dir" >&2
  exit 1
fi

# App Store icons must stay PNG. These sources are photographic RGBA (~4MB each);
# lossless recompression barely helps. Prefer pngquant when available; otherwise
# JPEG round-trip via sips strips unused alpha and typically lands ~1.2MB each.
install_compressed_app_icon() {
  local src="$1"
  local dst="$2"
  local tmp_jpeg size_label

  if command -v pngquant >/dev/null 2>&1; then
    if pngquant --force --skip-if-larger --quality=70-95 --output "$dst" "$src"; then
      size_label="$(du -h "$dst" | awk '{print $1}')"
      echo "  Installed $dst ($size_label, pngquant)"
      return 0
    fi
  fi

  tmp_jpeg="$(mktemp -t trinket-appicon).jpg"
  sips -s format jpeg -s formatOptions 85 "$src" --out "$tmp_jpeg" >/dev/null
  sips -s format png "$tmp_jpeg" --out "$dst" >/dev/null
  rm -f "$tmp_jpeg"
  size_label="$(du -h "$dst" | awk '{print $1}')"
  echo "  Installed $dst ($size_label)"
}

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
  if [[ "${FORCE_ASSET_REENCODE:-0}" != "1" ]] \
    && [[ -f "$target_dir/$dst" && ! "$source_dir/$src" -nt "$target_dir/$dst" ]]; then
    continue
  fi
  install_compressed_app_icon "$source_dir/$src" "$target_dir/$dst"
done

echo "=== App icon ready ==="
