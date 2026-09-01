# Artwork working-set retention

Status: active
Confidence: high

## Observation
Agents repeatedly try to reduce memory by dropping launch/imminent artwork pins, switching first-screen art to on-demand `Image(name)`, or lowering `PreparedArtworkMemoryBudget` / `NSCache.totalCostLimit` to re-target 4 GB devices.

## Why it matters
Those pins are hitch prevention — decode before the tap so deferred catalog warmup cannot evict them. `NSCache` alone is not sufficient. Removing them trades a visible hitch on first navigation for a small memory saving.

## Evidence
- `AGENTS.md` guardrail requires product approval before lowering the working-set budgets or dropping launch/imminent pins.
- `Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift` and `PreparedArtwork.swift` own decode-and-pin.
- `Scripts/check-artwork-budget.sh` validates budgets; `Scripts/check-agent-invariants.sh` (`ArtworkWorkingSetCheck`) blocks `releasePins` in `Trinket/App/TrinketApp.swift` without `allow` + rationale.
- `Docs/Platform/PerformanceInvestigationPlaybook.md` + `Docs/Platform/MemoryAndEnergyInvestigation.md` — investigation-owned, not routine optimization.

## Preferred pattern
Keep launch + imminent pins; decode before first paint; let the enforced physical-memory budget and `NSCache` cap evict naturally. Exact values live with the implementation and the performance playbook. First-layout tab roots under launch cover per `Trinket/Features/AGENTS.md`.

## Exceptions
Product-approved budget change with Instruments evidence and a forcing function (e.g., verified 4 GB target). Requires explicit `ArtworkWorkingSetCheck: allow - <reason>` nearby.

## Enforcement opportunity
Already encoded: `check-artwork-budget.sh` + `ArtworkWorkingSetCheck` in `check-agent-invariants.sh`. Keep prose guardrail lean; hard gate owns it.
