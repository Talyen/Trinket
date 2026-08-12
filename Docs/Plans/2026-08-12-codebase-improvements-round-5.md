# Codebase Improvement Plan — Round 5 (Bugs, Performance, Simplification, Tests)

Date: 2026-08-12  
Status: Proposed execution plan  
Scope: Whole-repo exploration for confirmed improvement candidates across four categories (Bugs, Performance, Simplification, Tests). Every item was verified by inspecting source code before inclusion.

Guiding rules applied:
- Deliver the smallest change that fully satisfies the requirement.
- Prefer delete → reuse → simplify → parameterize.
- Path-scoped verification with `--isolate` before handoff.

---

## Phase 1 — Correctness Fixes (Bugs)

### 1.1 `BattleConditionEvaluator.isMet(.allyBelowHalfHealth)` evaluates defeated allies as active allies below half health
- **Evidence:** [`BattleConditionEvaluator.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Sources/BattleEngine/BattleConditionEvaluator.swift#L34-L40) — `case .allyBelowHalfHealth:` calculates `heroHealth * 2 < heroMax || companionHealth * 2 < companionMax`. When the companion is defeated (`companionHealth == 0`), `0 * 2 < companionMax` evaluates to `0 < companionMax` (true), causing `.allyBelowHalfHealth` to trigger permanently even when the surviving hero is at full health (100% HP).
- **Fix:** Require `heroHealth > 0` and `companionHealth > 0` respectively: `(heroHealth > 0 && heroHealth * 2 < heroMax) || (companionHealth > 0 && companionHealth * 2 < companionMax)`.
- **LOC:** ~+2/-1.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 1.2 `BattleState.resolveDamage` over-deducts block buffer on zero-damage / health-cost damage requests
- **Evidence:** [`BattleState+CombatResolution.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Sources/BattleEngine/BattleState+CombatResolution.swift) — When resolving damage, shield buffer reduction checks `buffer > 0` before verifying if incoming damage is 0 or tagged as a direct health cost (which bypasses block).
- **Fix:** Guard block reduction with `guard request.amount > 0, !request.options.contains(.healthCost)` prior to deducting from active shield buffers.
- **LOC:** ~+2/-1.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

---

## Phase 2 — Performance Optimizations

### 2.1 `PlayerSaveSanitizer.adjacentPath` candidate iteration efficiency
- **Evidence:** [`PlayerSaveSanitizer.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveSanitizer.swift#L411-L419) — In `adjacentPath`, for every popped BFS node, it iterates over all `sortedNodeIDs` ($O(N)$), evaluating `!visited.contains(candidateID)` and doing `nodes[candidateID]` dictionary lookups repeatedly for already-visited nodes.
- **Fix:** Skip dictionary lookups for visited nodes during Labyrinth graph BFS.
- **LOC:** ~+3/-2.
- **Verify:** `./Scripts/test-package.sh TrinketPersistence`.

### 2.2 `BattleLogReducer.entries(from:startingAt:)` over-allocation of event capacity
- **Evidence:** [`BattleLogReducer.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Sources/BattleEngine/BattleLogReducer.swift#L20-L23) — `result.reserveCapacity(events.count - startIndex)` reserves capacity for every raw event, but `line(for: event)` drops `.abilityDamage` and non-displayable `.effect` events, causing over-allocated arrays during high-frequency battle event streaming.
- **Fix:** Reserve capacity based on realistic non-filtered event frequency estimation rather than raw event count.
- **LOC:** ~+2/-1.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

---

## Phase 3 — Simplification & Over-Engineering Removal

### 3.1 Remove inline forwarding wrapper `BattleCardCombatTests.makeBattle`
- **Evidence:** [`BattleCardCombatTests.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift#L7-L19) — `makeBattle(...)` is a 13-line private forwarding method inside `BattleCardCombatTests` that forwards all parameters directly to `BattleStateTestFactory.makeBattleWithAbilities(...)`.
- **Fix:** Call `BattleStateTestFactory.makeBattleWithAbilities(...)` directly across `BattleCardCombatTests.swift` and delete the redundant wrapper.
- **LOC:** ~-13.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 3.2 Remove redundant `@discardableResult` annotations in `ShopEncounterSession`
- **Evidence:** [`ShopEncounterSession.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketAppState/Sources/TrinketAppState/State/ShopEncounterSession.swift) — Methods with mandatory caller handling retain redundant `@discardableResult` annotations.
- **Fix:** Clean up redundant `@discardableResult` annotations to clarify exact return value usage contract.
- **LOC:** ~-2.
- **Verify:** `./Scripts/test-package.sh TrinketAppState`.

---

## Phase 4 — Test Optimization & Deduplication

### 4.1 Centralize passive combatant test helpers in `BattleStateTestFactory`
- **Evidence:** [`AffixReactionBattleTests.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Tests/BattleEngineTests/AffixReactionBattleTests.swift) and `CombatPipelineTests.swift` duplicate inline local helper functions creating zero-stat passive combatants.
- **Fix:** Add `passiveHero()`, `passiveCompanion()`, and `passiveEnemy()` static helpers to `BattleStateTestFactory` and reuse them across test suites.
- **LOC:** ~-18 across test files.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 4.2 Deduplicate `Combatant` initializations in `TrinketBattleFeature` tests
- **Evidence:** `Packages/TrinketBattleFeature/Tests/TrinketBattleFeatureTests/BattleSessionPreparationTests.swift` manually instantiates `Combatant(id: "hero", name: "Hero", ...)` instead of using `CombatantFixtures` from `TrinketTestSupport`.
- **Fix:** Refactor test setup to use `CombatantFixtures.combatant(...)`.
- **LOC:** ~-12 across test files.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature`.

---

## Verification Plan

### Automated Tests
- `./Scripts/test.sh unit`
- `./Scripts/test-package.sh BattleEngine`
- `./Scripts/test-package.sh TrinketPersistence`
- `./Scripts/test-package.sh TrinketAppState`
- `./Scripts/test-package.sh TrinketBattleFeature`

### Handoff Gate
- `./Scripts/handoff.sh --isolate --paths Packages/BattleEngine Packages/TrinketPersistence Packages/TrinketAppState Packages/TrinketBattleFeature`
