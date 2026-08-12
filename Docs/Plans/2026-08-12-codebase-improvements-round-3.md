# Codebase improvement plan — round 3 (bugs, performance, simplification, tests)

Date: 2026-08-12
Status: Proposed execution plan
Scope: Whole-repo exploration for confirmed improvement candidates across four categories (Bugs, Performance, Simplification, Tests). Every item was verified by reading the relevant code before inclusion.

Guiding rules applied: smallest change that removes the confirmed cause; prefer delete → reuse → simplify → parameterize; path-scoped verification before any commit.

---

## Phase 1 — Correctness fixes (Bugs)

### 1.1 `LabyrinthMapView.onAppear` swallows `labyrinth.enter()` failure message
- **Evidence:** `Packages/TrinketAppState/Sources/TrinketAppState/State/Modes/LabyrinthMapView.swift` — `.onAppear { _ = labyrinth.enter() }` discards the returned `StageMapMessage?`, whereas the manual Enter button checks `if let message = labyrinth.enter() { nodeMessage = message }`. When entering via deep-link or auto-navigation, any entry error message is lost.
- **Fix:** Update `onAppear` to capture the return value: `if let message = labyrinth.enter() { nodeMessage = message }`.
- **LOC:** ~+2/-1.
- **Verify:** `./Scripts/test-package.sh TrinketAppState`.

### 1.2 `RosterHydration` non-deterministic active hero fallback
- **Evidence:** `Packages/TrinketAppState/Sources/TrinketAppState/State/RosterHydration.swift:16-23` — `unlockedHeroIDs.first` returns an arbitrary element from an unordered `Set<String>`, causing non-deterministic hero selection on fresh/corrupted states across app relaunches.
- **Fix:** Order `unlockedHeroIDs` deterministically by catalog order or sort before selecting `.first`.
- **LOC:** ~+2/-1.
- **Verify:** `./Scripts/test-package.sh TrinketAppState`.

### 1.3 `ItemCorruption` sort with no effect before random element pick
- **Evidence:** `Packages/TrinketAppState/Sources/TrinketAppState/State/ItemCorruption.swift:80-81` — `eligible.sorted(by: ...).randomElement(using: &rng)` sorts the collection immediately before picking a random element, wasting CPU work and performing a pointless sort.
- **Fix:** Remove `.sorted(by: ...)` before `randomElement`.
- **LOC:** ~-1.
- **Verify:** `./Scripts/test-package.sh TrinketAppState`.

### 1.4 `PlayerState.item(matching:)` falls back to wrong item on ID miss
- **Evidence:** `Packages/TrinketAppState/Sources/TrinketAppState/State/PlayerState.swift:24-30` — When searching by item ID, if the exact ID is absent, it falls back to matching by `templateID`. In corruption/salvage scenarios, this displays a completely different item instance instead of `nil`.
- **Fix:** Strict exact-ID lookup in `item(matching:)`, returning `nil` on exact ID miss.
- **LOC:** ~-4.
- **Verify:** `./Scripts/test-package.sh TrinketAppState`.

---

## Phase 2 — Performance Optimizations

### 2.1 `CombatFeedbackChipBridge.updateAvailabilityWakeTime` scans all items on every publish
- **Evidence:** `Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Feedback/CombatFeedbackChipBridge.swift:100-110` — Iterates through `itemsByTarget.values` flatMap on every single `publish` call to update timer wake dates, scaling linearly with total accumulated chips ($O(N)$ per event).
- **Fix:** Track minimum next wake date incrementally upon insertion/removal ($O(1)$ per event), avoiding full-table iteration.
- **LOC:** ~+6/-4.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature`.

### 2.2 Status-effect overlay runs continuous unthrottled `TimelineView(.animation)` indefinitely
- **Evidence:** `Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Effects/CombatantCardStatusEffectVariants.swift:301-338` — Mounts `TimelineView(.animation)` that continuously redraws Canvas particle effects at display refresh rate for the entire duration of Stun/Freeze status, even after intro animations saturate (`progress >= 1`).
- **Fix:** Pause timeline updates when `progress >= 1` using `TimelineView(.animation(paused: true))` or standard non-animating view branch, eliminating unnecessary GPU/CPU redraws during idle turn states.
- **LOC:** ~+5/-2.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature`.

### 2.3 `BattleHandView` pre-computes layout snapshots
- **Evidence:** `Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/BattleHandView.swift:43-56` — `liveSnapshot` recalculates layout offsets inside `ForEach` for every card render pass rather than pre-calculating the snapshot array once for the hand.
- **Fix:** Pre-compute `liveSnapshots` array before `ZStack` rendering loop to avoid repeated math.
- **LOC:** ~+4/-2.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature`.

---

## Phase 3 — Simplification & Over-Engineering Removal

### 3.1 Unused wrapper `CombatTraitTriggers+CombatProfile.swift`
- **Evidence:** `Packages/BattleEngine/Sources/BattleEngine/CombatTraitTriggers+CombatProfile.swift` is a 10-line forwarding file containing a single helper that forwards directly to `CombatModifierProfile`.
- **Fix:** Inline the helper into `CombatModifierProfile.swift` and delete the redundant single-helper file.
- **LOC:** ~-10 (file deleted).
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 3.2 Simplify `recordAction` & `drawCards` return value contracts
- **Evidence:** `BattleTurnEngine.swift` and `BattleCardCombatEngine.swift` have leftover unused return signatures or `@discardableResult` annotations where callers ignore the returned count/array.
- **Fix:** Make return signatures `Void` where return values are consistently ignored across call sites.
- **LOC:** ~-5.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

---

## Phase 4 — Test Optimization & Deduplication

### 4.1 Consolidate duplicated `Combatant` test fixtures across `BattleEngineTests`
- **Evidence:** Multiple test files in `Packages/BattleEngine/Tests/BattleEngineTests/` (`AbilityEffectIntegrationTests.swift`, `AffixReactionBattleTests.swift`, `BattleCardCombatTests.swift`, `BattleLogReducerTests.swift`, `BattleStateTests.swift`) create inline `Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, ...)` boilerplate repeatedly instead of using `BattleTestFixtures.passiveCombatant` or `BattleStateTestFactory`.
- **Fix:** Centralize test combatant creation in `BattleStateTestFactory` and replace duplicated inline `Combatant` instantiations across test files.
- **LOC:** ~-35 across test files.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 4.2 Deduplicate `BattleSession` command delay testing helpers
- **Evidence:** `Packages/TrinketBattleFeature/Tests/TrinketBattleFeatureTests/` contains copied helper functions for seeding battle test state and advancing timing.
- **Fix:** Extract shared battle feature test helpers into `BattleFeatureTestSupport.swift` to clean up duplicate test setup code.
- **LOC:** ~-20 across feature test files.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature`.

---

## Verification Plan

### Automated Tests
- `./Scripts/test.sh unit` (Runs all package unit tests in parallel).
- `./Scripts/test-package.sh BattleEngine`
- `./Scripts/test-package.sh TrinketBattleFeature`
- `./Scripts/test-package.sh TrinketAppState`

### Handoff Gate
- `./Scripts/handoff.sh --isolate --paths Packages/BattleEngine Packages/TrinketBattleFeature Packages/TrinketAppState`
