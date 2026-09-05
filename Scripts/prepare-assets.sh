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
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--kind art|cinematic|music|sfx|app-icon|all]"
      exit 0
      ;;
    *)
      echo "Unknown arg '$1' (expected --kind art|cinematic|music|sfx|app-icon|all)" >&2
      exit 1
      ;;
  esac
fi

if [[ $# -gt 0 ]]; then
  echo "Unexpected argument: $1" >&2
  exit 2
fi
case "$kind" in
  art|cinematic|music|sfx|app-icon|all) ;;
  *) echo "Unknown asset kind: $kind" >&2; exit 2 ;;
esac

run_kind() {
  echo "=== Preparing $1 ==="
  case "$1" in
    art) Scripts/prepare-art-assets.sh ;;
    cinematic) Scripts/prepare-cinematic-assets.sh ;;
    music) Scripts/prepare-audio-assets.sh music ;;
    sfx) Scripts/prepare-audio-assets.sh sfx ;;
    app-icon) Scripts/prepare-app-icon.sh ;;
  esac
}

case "$kind" in
  all)
    for _kind in art cinematic music sfx app-icon; do
      run_kind "$_kind"
    done
    ;;
  *)
    run_kind "$kind"
    ;;
esac
