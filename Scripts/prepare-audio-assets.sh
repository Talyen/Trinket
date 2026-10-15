#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
kind="${1:-all}"
case "$kind" in
  all) kind=audio ;;
  music|sfx) ;;
  --help|-h) echo "Usage: $0 [music|sfx|all]"; exit 0 ;;
  *) echo "Unknown kind: $kind" >&2; exit 1 ;;
esac
exec python3 Scripts/prepare-media.py "$kind" "${@:2}"
