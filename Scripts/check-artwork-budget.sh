#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck source=Scripts/lib/rg-check.sh
source "$(dirname "$0")/lib/rg-check.sh"

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: $0"
  echo "Enforce runtime artwork cache budgets (constants only; never media output sizes)."
  exit 0
fi

# Scope: runtime cache constants only, not media-pipeline output sizes.
# Despite the name, this never touches Trinket/Assets.xcassets or Trinket/Media;
# see Scripts/check-unused-assets.py for pipeline orphan/missing coverage.

TRINKET_RG_BULLET="  - "

# Enforce 6 GB typical budgets. Do not lower to re-target 4 GB without product approval.
# See Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift
# and Docs/Platform/PerformanceInvestigationPlaybook.md § Artwork Budgets.
# Scope: runtime cache constants only, not manifest pipeline output sizes.

file="Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift"

search() {
  trinket_rg_contains "$1" "$2"
}

# Anchored to assignment/cost-limit call sites to avoid matching prose comments.
if ! search "residentArtworkByteCount = 320 \* 1024 \* 1024" "$file"; then
  trinket_rg_violation "$file: residentArtworkByteCount must be 320 MiB (6 GB typical). See PerformanceInvestigationPlaybook § Artwork Budgets."
fi
if ! search "steadyStateProcessByteCount = 550 \* 1024 \* 1024" "$file"; then
  trinket_rg_violation "$file: steadyStateProcessByteCount must be 550 MiB (6 GB typical)."
fi
if ! search "totalCostLimit\(forPhysicalMemory|.*160 \* 1024 \* 1024" "$file"; then
  trinket_rg_violation "$file: NSCache floor must be 160 MiB (not 96)."
fi
if ! search "260 \* 1024 \* 1024" "$file"; then
  trinket_rg_violation "$file: NSCache cap must be 260 MiB (not 160)."
fi
# Forbid the old 4 GB-targeted 96 MiB floor assignment (ignore prose like "Do not lower floor to 96").
if search "^\s*[^/]*96 \* 1024 \* 1024" "$file"; then
  trinket_rg_violation "$file: 96 MiB floor is the old 4 GB target — do not reintroduce without product approval."
fi

trinket_rg_report "Artwork budget violations:" "Artwork budgets OK (6 GB typical: 320/550, cache 160-260)."
