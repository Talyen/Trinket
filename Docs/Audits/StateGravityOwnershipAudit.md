# State Gravity & Ownership Audit

**Goal:** Pull misplaced rules, persistence, and presentation logic out of gravity wells (`AppState`, fat sessions, mega-views) into the owners defined by Architecture — without inventing new hubs.

## Intent

Restore ownership-drift clusters to existing owners. Move, do not mirror: delete old forwarding APIs, parallel paths, and duplicate tests. New sessions/managers must express a real lifetime boundary and replace more surface than they add. Significant moves remain proposals per [README.md](README.md).

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

**Not this audit:** import-gate failures alone → repair directly through `check-module-boundaries.sh`; unused APIs → DeadCode; verbose ceremony with correct ownership → InelegantSlop; duplicate screens with correct owners → DuplicateFeatureSurface; silent save bugs without ownership drift → BehaviorHardening.

## Hard stops

- Do not relocate battle simulation off `@MainActor` unless Architecture already requires it.
- Do not collapse intentional seams: battle RNG injection, persistence write coalescing, catalog/codegen boundaries, Options/`UserDefaults` vs `PlayerSave`.
- Do not move presentation into packages that must stay SwiftUI-free of feature views (`BattleEngine`, `TrinketPersistence`, `TrinketCore`).
- Repair a failing `check-module-boundaries.sh` row directly when it has an obvious one-file fix rather than expanding it into an ownership audit.

## Evidence bar

Wrong owner per [Architecture.md](../Platform/Architecture.md), real review/test cost
from mixed jobs on one type, and an existing home (engine handler, store slice,
Battle presentation lane, `TrinketFeatureSupport`, or feature session)—not a
greenfield layer.

## Domain rules

Follow Architecture ownership and app-layer imports:

| Concern | Owner |
|---------|-------|
| Effects, stats, progression primitives | `TrinketCore` |
| Catalogs / generated content | `TrinketContent` |
| Card combat rules | `BattleEngine` (`EffectHandlers/`, engines, `BattleState+*` plumbing) |
| Save graph, stores, CloudKit wiring | `TrinketPersistence` |
| Shared chrome | `TrinketDesignSystem` |
| Tab shell, sessions, options | `Packages/TrinketAppState` |
| Product screens | `Trinket/Features` |
| Active battle configuration / battle outcome | `Packages/TrinketBattleFeature` |
| Game-specific shared UI | `Packages/TrinketFeatureSupport` |

**Hub containment** (Architecture): keep `BattleState` and `PlayerSaveStore` thin — new work goes to handlers, engines, store slices, or `+` plumbing files, not feature-specific methods on the hub.

**Module layers:** `TrinketFeatureSupport` must stay below `TrinketBattleFeature` and
`TrinketAppState`; Battle must not import AppState; packages must not import the app
module.

Prefer restoring rules to engines/stores, keeping tab/session wiring on thin
`AppState` / `*Session` types, and extracting reusable presentation into
`TrinketFeatureSupport`. Propose hub splits when local moves would leave the same
gravity well intact.
