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
      kind="${2:-all}"
      ;;
    art|cinematic|music|sfx|all)
      kind="$1"
      ;;
    --help|-h)
      echo "Usage: $0 [--kind art|cinematic|music|sfx|all]"
      exit 0
      ;;
    *)
      echo "Unknown arg '$1' (expected --kind art|cinematic|music|sfx|all or art|cinematic|music|sfx|all)" >&2
      exit 1
      ;;
  esac
fi

case "$kind" in
  art) Scripts/prepare-art-assets.sh ;;
  cinematic) Scripts/prepare-cinematic-assets.sh ;;
  music) Scripts/prepare-music-assets.sh ;;
  sfx) Scripts/prepare-sfx-assets.sh ;;
  all)
    Scripts/prepare-art-assets.sh
    Scripts/prepare-cinematic-assets.sh
    Scripts/prepare-music-assets.sh
    Scripts/prepare-sfx-assets.sh
    ;;
  *)
    echo "Unknown kind '$kind'" >&2; exit 1
    ;;
esac
