# State Gravity & Ownership Audit

**Goal:** Pull misplaced rules, persistence, and presentation logic out of gravity wells (`AppState`, fat sessions, mega-views) into the owners defined by Architecture — without inventing new hubs.

**Siblings:** package/layer import gate → [ImportCouplingBoundaryAudit.md](ImportCouplingBoundaryAudit.md); copy-paste screens → [DuplicateFeatureSurfaceAudit.md](DuplicateFeatureSurfaceAudit.md); ceremony / wrappers → [InelegantSlopAudit.md](InelegantSlopAudit.md); persistence correctness → [BehaviorHardeningAudit.md](BehaviorHardeningAudit.md); combat/RNG seams → [SideEffectSurfaceAudit.md](SideEffectSurfaceAudit.md).

## Intent

Confirm one cohesive ownership drift cluster: logic that accumulated in `Trinket/State`, a giant feature view, or a facade hub that Architecture says should stay thin. Restore ownership to the existing package or layer. A clean pass is valid. Local moves that fully restore ownership may ship in-pass; significant extractions, package moves, or hub splits are propose-and-stop per [README.md](README.md).

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

**Not this audit:** import-gate failures alone → ImportCoupling; unused APIs → DeadCode; verbose ceremony with correct ownership → InelegantSlop; duplicate screens with correct owners → DuplicateFeatureSurface; silent save bugs without ownership drift → BehaviorHardening.

## Hard stops

- Do not invent a new package, DI container, or second app-wide store to “fix” gravity.
- Do not relocate battle simulation off `@MainActor` unless Architecture already requires it.
- Do not collapse intentional seams: battle RNG injection, persistence write coalescing, catalog/codegen boundaries, Options/`UserDefaults` vs `PlayerSave`.
- Do not move presentation into packages that must stay SwiftUI-free of feature views (`BattleEngine`, `TrinketPersistence`, `TrinketCore`).
- Do not change player-facing balance, copy, or `accessibilityIdentifier` values unless required to restore a broken boundary.
- Prefer ImportCoupling when the only issue is a failing `check-module-boundaries.sh` row with an obvious one-file fix.

## Confirm before fixing

1. **Wrong owner:** the code’s concern matches a different row in [Architecture.md](../Platform/Architecture.md) module ownership or hub containment.
2. **Real cost:** the hub/view is hard to test, review, or extend because unrelated jobs share its type.
3. **Existing home:** the target owner already exists (engine handler, store slice, `BattleShell`, `Shared/`, feature session) — not a greenfield layer.
4. **Blast radius:** one cluster (e.g. encounter orchestration, or homestead mutations on `AppState`) — do not flatten all of `AppState` in one unsupervised pass.

## Restoration order

1. **Move** pure rules into `BattleEngine` / `TrinketCore` with package tests proving behavior.
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

Size/`AppState+*` surface area; methods on `AppState` / `BattleSession` that encode battle math, reward policy, or save sanitizing; feature views that call persistence APIs with inline business rules; growth of `BattleState` / `PlayerSaveStore` type bodies; new `*Manager`/`*Coordinator` types beside existing sessions. Cross-check against Architecture module and hub tables before proposing a move.

## Verify

`check-module-boundaries.sh` + `lint.sh` always. Package tests for moved rules (`test-package.sh BattleEngine` / `TrinketPersistence` as touched). Focused `test.sh unit` / smoke when `AppState` or feature flows change. `build.sh` when imports move across targets (toolchain permitting).
