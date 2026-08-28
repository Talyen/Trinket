# Artwork working-set retention

Status: active
Confidence: high

## Observation
Agents repeatedly try to reduce memory by dropping launch/imminent artwork pins, switching first-screen art to on-demand `Image(name)`, or lowering `PreparedArtworkMemoryBudget` / `NSCache.totalCostLimit` to re-target 4 GB devices.

## Why it matters
Those pins are hitch prevention — decode before the tap so deferred catalog warmup cannot evict them. `NSCache` alone is not sufficient. Removing them trades a visible hitch on first navigation for a small memory saving.

## Evidence
- `AGENTS.md` guardrail: budgets tuned for 6 GB typical (320 MiB artwork / 550 MiB process / 260 MiB cache cap, `physicalMemory/24` floored to 160).
- `Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift` and `PreparedArtwork.swift` own decode-and-pin.
- `Scripts/check-artwork-budget.sh` validates budgets; `Scripts/check-agent-invariants.sh` (`ArtworkWorkingSetCheck`) blocks `releasePins` in `Trinket/App/TrinketApp.swift` without `allow` + rationale.
- `Docs/Platform/PerformanceInvestigationPlaybook.md` + `Docs/Platform/MemoryAndEnergyInvestigation.md` — investigation-owned, not routine optimization.

## Preferred pattern
Keep launch + imminent pins; decode before first paint; let `PhysicalMemory` budget + `NSCache` cap evict naturally. First-layout tab roots under launch cover per `Trinket/Features/AGENTS.md`.

## Exceptions
Product-approved budget change with Instruments evidence and a forcing function (e.g., verified 4 GB target). Requires explicit `ArtworkWorkingSetCheck: allow - <reason>` nearby.

## Enforcement opportunity
Already encoded: `check-artwork-budget.sh` + `ArtworkWorkingSetCheck` in `check-agent-invariants.sh`. Keep prose guardrail lean; hard gate owns it.
