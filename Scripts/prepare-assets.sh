#!/usr/bin/env bash
set -euo pipefail
# Unified dispatch for media pipelines — delegates to kind-specific prepare scripts.
# LC_ALL=C sort is handled by delegated scripts; header-preserving sort uses
# head -n 2 and tail -n +3 in lib/media-assets.sh; unchanged outputs use cmp -s.

cd "$(dirname "$0")/.."

kind="all"
if [[ $# -ge 1 ]]; then
  case "$1" in
    --kind)
      if [[ -z "${2:-}" ]]; then
        echo "--kind requires an argument (art|cinematic|music|sfx|app-icon|all)" >&2
        exit 2
      fi
      kind="$2"
      ;;
    art|cinematic|music|sfx|app-icon|all)
      kind="$1"
      ;;
    --help|-h)
      echo "Usage: $0 [--kind art|cinematic|music|sfx|app-icon|all]"
      exit 0
      ;;
    *)
      echo "Unknown arg '$1' (expected --kind art|cinematic|music|sfx|app-icon|all or art|cinematic|music|sfx|app-icon|all)" >&2
      exit 1
      ;;
  esac
fi

case "$kind" in
  art) echo "=== Preparing art ==="; Scripts/prepare-art-assets.sh ;;
  cinematic) echo "=== Preparing cinematic ==="; Scripts/prepare-cinematic-assets.sh ;;
  music) echo "=== Preparing music ==="; Scripts/prepare-music-assets.sh ;;
  sfx) echo "=== Preparing sfx ==="; Scripts/prepare-sfx-assets.sh ;;
  app-icon) echo "=== Preparing app-icon ==="; Scripts/prepare-app-icon.sh ;;
  all)
    echo "=== Preparing art ==="; Scripts/prepare-art-assets.sh
    echo "=== Preparing cinematic ==="; Scripts/prepare-cinematic-assets.sh
    echo "=== Preparing music ==="; Scripts/prepare-music-assets.sh
    echo "=== Preparing sfx ==="; Scripts/prepare-sfx-assets.sh
    echo "=== Preparing app-icon ==="; Scripts/prepare-app-icon.sh
    ;;
  *)
    echo "Unknown kind '$kind'" >&2; exit 1
    ;;
esac
