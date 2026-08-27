#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

violations=()

# Enforce 6 GB typical budgets. Do not lower to re-target 4 GB without product approval.
# See Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift
# and Docs/Platform/PerformanceInvestigationPlaybook.md § Artwork Budgets.

file="Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift"

search() {
  local pattern="$1" target="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -q --no-ignore -g '!*' "$pattern" "$target" 2>/dev/null
  else
    grep -Eq "$pattern" "$target"
  fi
}

# Anchored to assignment/cost-limit call sites to avoid matching prose comments.
if ! search "residentArtworkByteCount = 320 \* 1024 \* 1024" "$file"; then
  violations+=("$file: residentArtworkByteCount must be 320 MiB (6 GB typical). See PerformanceInvestigationPlaybook § Artwork Budgets.")
fi
if ! search "steadyStateProcessByteCount = 550 \* 1024 \* 1024" "$file"; then
  violations+=("$file: steadyStateProcessByteCount must be 550 MiB (6 GB typical).")
fi
if ! search "totalCostLimit\(forPhysicalMemory|.*160 \* 1024 \* 1024" "$file"; then
  violations+=("$file: NSCache floor must be 160 MiB (not 96).")
fi
if ! search "260 \* 1024 \* 1024" "$file"; then
  violations+=("$file: NSCache cap must be 260 MiB (not 160).")
fi
# Forbid the old 4 GB-targeted 96 MiB floor assignment (ignore prose like "Do not lower floor to 96").
if search "^\s*[^/]*96 \* 1024 \* 1024" "$file"; then
  violations+=("$file: 96 MiB floor is the old 4 GB target — do not reintroduce without product approval.")
fi

if (( ${#violations[@]} > 0 )); then
  echo "Artwork budget violations:" >&2
  for v in "${violations[@]}"; do echo "  - $v" >&2; done
  exit 1
fi
echo "Artwork budgets OK (6 GB typical: 320/550, cache 160-260)."
