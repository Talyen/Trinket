# Module DAG and hub containment

Status: active
Confidence: high

## Observation
Agents add convenience imports that violate the package DAG or fatten hub facades (`BattleState`, `PlayerSaveStore`, `AppState`) instead of placing logic in the owning module.

## Why it matters
Reverse edges create circular dependencies, leak persistence/battle concerns into reusable UI, and turn thin facades into god objects. The DAG is the primary architecture invariant; hub containment keeps mutation surfaces reviewable.

## Evidence
- `Docs/Platform/Architecture.md` — dependency rules and hub-containment table (`BattleState` → `EffectHandlers/`, `DamagePipeline`; `PlayerSaveStore` → `Models/` + `+Homestead/+Roster` extensions; `AppState` → wiring only).
- `Scripts/check-module-boundaries.sh` — enforced in source imports and `Package.swift` manifests (DesignSystem→Core only, BattleEngine↔Persistence siblings, FeatureSupport below BattleFeature/AppState, AppState→BattleEngine via `BattleRuntime` contract).
- Nested `AGENTS.md` in `Packages/BattleEngine`, `TrinketBattleFeature`, `TrinketPersistence`, `TrinketDesignSystem` restate local hard stops.

## Preferred pattern
Depend downward only (app → AppState/BattleFeature/FeatureAdapters → FeatureSupport → Content → Core). Keep `BattleState` API to reads + `playCard`/`endTurn`/log; engine mutations are `package` in `BattleState+*.swift`. Keep `AppState` as composition root via `PlayBattleLaunch`/`PlayBattleCompletion`.

## Exceptions
None without product approval. Deferred splits are intentional until a third consumer forces the seam: `TrinketContent` (catalogs vs procedural), `TrinketFeatureSupport` (by domain), further Battle presentation splitting — see `Architecture.md` deferred table.

## Enforcement opportunity
Already encoded as hard enforcement (`check-module-boundaries.sh` in `handoff.sh` cheap slices and `ci-gate.sh`). Prefer that gate over prompt repetition.
