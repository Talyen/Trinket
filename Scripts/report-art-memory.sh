#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

manifest="ArtManifest/curated-assets.tsv"
asset_catalog="Trinket/Assets.xcassets"
budget_mib="${ART_CATALOG_DECODED_MEMORY_BUDGET_MIB:-1024}"
enforce=false

if [[ "${1:-}" == "--enforce" ]]; then
  enforce=true
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--enforce]" >&2
  exit 2
fi

if ! [[ "$budget_mib" =~ ^[1-9][0-9]*$ ]]; then
  echo "ART_CATALOG_DECODED_MEMORY_BUDGET_MIB must be a positive integer (got: $budget_mib)" >&2
  exit 2
fi

report_temp="$(mktemp)"
mapping_temp="$(mktemp)"
cleanup() {
  rm -f "$report_temp" "$mapping_temp"
}
trap cleanup EXIT INT TERM

awk -F $'\t' '!/^#/ && NF >= 3 { print $3 "\t" $1 }' "$manifest" > "$mapping_temp"

while IFS= read -r image_file; do
  asset_name="$(basename "$(dirname "$image_file")" .imageset)"
  base_name="${asset_name%_thumb}"
  kind="$(awk -F $'\t' -v name="$base_name" '$1 == name { print $2; exit }' "$mapping_temp")"
  [[ -n "$kind" ]] || continue

  variant="full"
  if [[ "$asset_name" == *_thumb ]]; then
    variant="thumb"
  fi

  dimensions="$(
    sips -g pixelWidth -g pixelHeight "$image_file" 2>/dev/null \
      | awk '/pixelWidth:/{ width=$2 } /pixelHeight:/{ height=$2 } END { print width, height }'
  )"
  read -r width height <<< "$dimensions"
  [[ -n "${width:-}" && -n "${height:-}" ]] || continue
  decoded_bytes=$((width * height * 4))
  printf '%s\t%s\t%d\n' "$kind" "$variant" "$decoded_bytes" >> "$report_temp"
done < <(rg --files "$asset_catalog" | rg '\.(heic|png|jpe?g)$' | sort)

printf '%-18s %8s %14s\n' "Asset group" "Count" "Decoded MiB"
awk -F $'\t' '
  {
    key = $1 " " $2
    count[key] += 1
    bytes[key] += $3
  }
  END {
    for (key in count) {
      printf "%-18s %8d %14.1f\n", key, count[key], bytes[key] / 1048576
    }
  }
' "$report_temp" | sort

total_bytes="$(awk -F $'\t' '{ total += $3 } END { printf "%.0f", total }' "$report_temp")"
total_mib="$(awk -v bytes="$total_bytes" 'BEGIN { printf "%.1f", bytes / 1048576 }')"
printf '\nEstimated full-catalog RGBA decode: %s MiB\n' "$total_mib"
printf 'Full-catalog decoded ceiling: %s MiB\n' "$budget_mib"

budget_bytes=$((budget_mib * 1024 * 1024))
if ((total_bytes > budget_bytes)); then
  printf 'Budget status: over by %.1f MiB\n' "$(awk -v total="$total_bytes" -v budget="$budget_bytes" 'BEGIN { print (total - budget) / 1048576 }')"
  if $enforce; then
    exit 1
  fi
else
  printf 'Budget status: within by %.1f MiB\n' "$(awk -v total="$total_bytes" -v budget="$budget_bytes" 'BEGIN { print (budget - total) / 1048576 }')"
fi
