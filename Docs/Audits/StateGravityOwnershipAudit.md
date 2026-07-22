# State Gravity & Ownership Audit

**Goal:** Pull misplaced rules, persistence, and presentation logic out of gravity wells (`AppState`, fat sessions, mega-views) into the owners defined by Architecture — without inventing new hubs.

## Intent

Confirm one ownership-drift cluster and restore it to an existing owner. Move, do not mirror: delete old forwarding APIs, parallel paths, and duplicate tests. New sessions/managers must express a real lifetime boundary and replace more surface than they add. Significant moves remain proposals per [README.md](README.md).

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

## Confirm before fixing

1. **Wrong owner:** the code’s concern matches a different row in [Architecture.md](../Platform/Architecture.md) module ownership or hub containment.
2. **Real cost:** the hub/view is hard to test, review, or extend because unrelated jobs share its type.
3. **Existing home:** the target owner already exists (engine handler, store slice, `BattleShell`, `Shared/`, feature session) — not a greenfield layer.
4. **Blast radius:** one cluster (e.g. encounter orchestration, or homestead mutations on `AppState`) — do not flatten all of `AppState` in one unsupervised pass.

## Restoration order

1. **Move** pure rules into `BattleEngine` / `TrinketCore`; reuse or relocate the existing semantic test owner rather than duplicating it.
2. **Move** persistence policy into `TrinketPersistence` store slices / sanitizer / models — keep `PlayerSaveStore` a thin facade.
3. **Keep** tab orchestration, launch args, and cross-feature session wiring on `AppState` / thin `*Session` types in `Trinket/State`.
4. **Keep** active-battle config and victory orchestration in `BattleShell/` (must not import `Features/`).
5. **Extract** presentation-only helpers into `Trinket/Shared/` or the feature folder; collapse duplicate shells via DuplicateFeatureSurface when that is the bulk of the win.
6. **Propose** hub splits or large `AppState` extractions when local moves would leave the same gravity well intact.

## Domain rules

Follow Architecture ownership and app-layer imports:

| Concern | Owner |
|---------|-------|
| Effects, stats, progression primitives | `TrinketCore` |
| Catalogs / generated content | `TrinketContent` |
| Card combat rules | `BattleEngine` (`EffectHandlers/`, engines, `BattleState+*` plumbing) |
| Save graph, stores, CloudKit wiring | `TrinketPersistence` |
| Shared chrome | `TrinketDesignSystem` |
| Tab shell, sessions, options | `Trinket/State`, `Trinket/App` |
| Product screens | `Trinket/Features` |
| Active battle configuration / victory glue | `Trinket/BattleShell` |
| Game-specific shared UI | `Trinket/Shared` |

**Hub containment** (Architecture): keep `BattleState` and `PlayerSaveStore` thin — new work goes to handlers, engines, store slices, or `+` plumbing files, not feature-specific methods on the hub.

**App layers:** `State/` must not import feature views; `BattleShell/` must not import `Features/`; packages must not import app feature UI.

## Probe hints

- **Deep Binding Prop Drilling:** Search for `@Binding` or closure callbacks passed through ≥3 levels of view hierarchy (e.g. `PlayView` → `PlayBrowsingStack` → `PlayMap` → `StageNodeView`); prefer scoped `@Environment` or session bindings.
- **Overly Broad Environment State Redraws:** Search for `@Environment(AppState.self)` or `@Bindable var session` in sub-views that only read 1 scalar property; evaluate extracting sub-views or scoped observation properties to reduce unnecessary re-evaluations.
- **Transient UI State Leaks in Persistence:** Search `Packages/TrinketPersistence/` and `PlayerSaveStore.swift` for transient UI states (e.g., `isHovered`, `selectedItem`, `activeTab`, `scrollOffset`) that belong exclusively in view local `@State`.
- **Misplaced Business Logic on `AppState` Extensions:** Search `AppState+*.swift` for inline damage calculations, gold cost math, or item generation logic that belongs in `BattleEngine` or `TrinketContent`.
- **Hub Body Bloat:** Search `BattleState.swift` and `PlayerSaveStore.swift` for feature-specific public methods; verify whether logic belongs in domain effect handlers (`EffectHandlers/`) or store extensions.
- **Invented Parallel Gravity Wells:** Search for regex `(struct|class)\s+\w*(Manager|Coordinator)` created alongside `AppState` for single-feature orchestration.
