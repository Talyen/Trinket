# 13. State Gravity & Ownership Audit

**Goal:** Pull misplaced rules, persistence, and presentation logic out of gravity wells (`AppState`, fat sessions, mega-views) into the owners defined by Architecture — without inventing new hubs.

## Intent

Restore ownership-drift clusters to existing owners. Include callers, mirrored/derived state, persistence or presentation adapters, and tests necessary to complete the move. Move, do not mirror: delete old forwarding APIs, parallel paths, duplicate state, and duplicate tests. New sessions/managers must express a real lifetime boundary and replace more surface than they add.

## What “state gravity” means here

Agentic coding often drops the next method on the nearest large type. Gravity wells grow until every concern shares one lifetime and one file surface.

| Tell | Why it is a finding |
|------|---------------------|
| Combat rules / damage / deck math in `AppState` or feature views | Belongs in `BattleEngine` |
| Save mutation, sanitizer, or store policy in Features / `AppState` methods | Belongs in `TrinketPersistence` / store slices |
| Feature navigation and screen-only UI state on persistence types | Presentation leaked downward |
| `BattleState` / `PlayerSaveStore` type bodies growing feature-specific APIs | Violates Architecture hub containment |
| Mega-view `body` that orchestrates rewards, catalog lookups, and mutations | View owns too many jobs; extract session/store or shared UI |
| New `*Manager` / parallel hub beside `AppState` for one flow | Invented gravity well instead of an extension on the real owner |
| Mirrored mutable state or duplicated derived state across view/session/store | Competing owners can diverge and make lifecycle or mutation order ambiguous |
| Callers validate or sequence an invariant that belongs to an engine/store | Ownership is distributed across entry points instead of enforced once |

**Not this audit:** import-gate failures alone → repair directly through `check-module-boundaries.sh`; correct owner with leftover twin / shim → DualPathRetention; verbose ceremony with correct ownership → InelegantSlop.

## Hard stops

- Do not relocate battle simulation off `@MainActor` unless Architecture already requires it.
- Do not collapse seams recorded as accepted non-findings in [Proposals.md](Proposals.md) (battle RNG injection, persistence write coalescing, catalog/codegen boundaries).
- Do not move presentation into packages that must stay SwiftUI-free of feature views (`BattleEngine`, `TrinketPersistence`, `TrinketCore`).
- Repair a failing `check-module-boundaries.sh` row directly when it has an obvious one-file fix rather than expanding it into an ownership audit.

## Evidence bar

All of:

- **Wrong owner** per [Architecture.md](../Platform/Architecture.md)
- **Real cost:** review or test cost from mixed jobs sharing one type or lifetime
- **Existing home:** engine handler, store slice, Battle presentation lane, `TrinketFeatureSupport`, or feature session — not a greenfield layer

When these hold, the remediation envelope includes migrating affected callers and tests, deleting mirrored state/forwarders, and updating configuration or documentation that names the old owner. Do not stop after moving only the core method.

## Domain rules

Ownership and layering live in [Architecture.md](../Platform/Architecture.md) (module DAG, ownership table, hub containment for `BattleState` / `PlayerSaveStore`, enforced import rules via `check-module-boundaries.sh`).

Prefer restoring rules to engines/stores, keeping tab/session wiring on thin
`AppState` / `*Session` types, and extracting reusable presentation into
`TrinketFeatureSupport`. Phase a hub split through existing Architecture owners when
it is bounded and removes the old path; propose only when the remedy needs a new
owner, lifetime boundary, package direction, or product decision.
