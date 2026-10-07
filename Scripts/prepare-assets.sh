#!/usr/bin/env bash
set -euo pipefail
# Unified dispatch for media pipelines — delegates to kind-specific prepare scripts.
# LC_ALL=C sort is handled by delegated scripts; header-preserving sort uses
# head -n 2 and tail -n +3 in lib/media-assets.sh; unchanged outputs use cmp -s.

cd "$(dirname "$0")/.."
# shellcheck source=Scripts/lib/args.sh
source Scripts/lib/args.sh

kind="all"
check=false
outputs_only=false
heal=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) check=true; shift ;;
    --outputs-only) outputs_only=true; shift ;;
    --heal) heal=true; shift ;;
    --kind)
      if [[ -z "${2:-}" ]]; then
        echo "--kind requires an argument (art|cinematic|music|sfx|app-icon|all)" >&2
        exit 2
      fi
      kind="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--kind art|cinematic|music|sfx|app-icon|all] [--check [--outputs-only]]"
      echo "       $0 --heal [--kind <kind>] (local relinking and preparation of relocated sources only)"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1 (expected --kind art|cinematic|music|sfx|app-icon|all)" >&2
      exit 1
      ;;
  esac
done
if $heal && $check; then
  echo "--heal cannot be combined with --check" >&2
  exit 2
fi
case "$kind" in
  art|cinematic|music|sfx|app-icon|all) ;;
  *) echo "Unknown asset kind: $kind" >&2; exit 2 ;;
esac

if $outputs_only && ! $check; then
  echo "--outputs-only requires --check" >&2
  exit 2
fi
if $check; then
  args=(--check --kind "$kind")
  $outputs_only && args+=(--outputs-only)
  python3 Scripts/asset-library.py "${args[@]}"
  exit
fi
run_kind() {
  trinket_log_section "Preparing $1"
  case "$1" in
    art) Scripts/prepare-art-assets.sh ;;
    cinematic) Scripts/prepare-cinematic-assets.sh ;;
    music) Scripts/prepare-audio-assets.sh music ;;
    sfx) Scripts/prepare-audio-assets.sh sfx ;;
    app-icon) Scripts/prepare-app-icon.sh ;;
  esac
}

if $heal; then
  # Ordinary builds remain source-free on CI and Macs without the local library.
  if [[ "${CI:-}" == true || "${GITHUB_ACTIONS:-}" == true || ! -d "${ASSET_LIBRARY_ROOT:-$HOME/Documents/Asset Library}" ]]; then
    exit 0
  fi
  relocated="$(python3 Scripts/asset-library.py --relink --apply --kind "$kind")"
  while IFS= read -r relocated_kind; do
    [[ -n "$relocated_kind" ]] && run_kind "$relocated_kind"
  done <<< "$relocated"
  exit 0
fi

python3 Scripts/asset-library.py --preflight --kind "$kind"

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
