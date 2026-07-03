#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

manifest_dir="ContentManifest"
required_manifests=(
  "$manifest_dir/affixes.tsv"
  "$manifest_dir/abilities.tsv"
)

for manifest in "${required_manifests[@]}"; do
  if [[ ! -f "$manifest" ]]; then
    echo "Missing manifest: $manifest" >&2
    exit 1
  fi
done

python3 Scripts/content_codegen.py
