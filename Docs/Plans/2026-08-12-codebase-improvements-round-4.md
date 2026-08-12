# Codebase improvement plan — round 4 (bugs, performance, simplification, tests)

Date: 2026-08-12
Status: Proposed execution plan
Scope: Whole-repo exploration for confirmed improvement candidates across four categories (Bugs, Performance, Simplification, Tests). Every item was verified by reading the relevant code before inclusion.

Guiding rules applied: smallest change that removes the confirmed cause; prefer delete → reuse → simplify → parameterize; path-scoped verification before any commit.

---

## Phase 1 — Correctness fixes (Bugs)

### 1.1 `GameContent+MysteryEvents.swift` redundant `.sorted()` before `.randomElement(using: &rng)`
- **Evidence:** `Packages/TrinketContent/Sources/TrinketContent/GameContent+MysteryEvents.swift:145` & `175` — `pickRandomNonBossEnemyID` calls `nonBossEnemies.map(\.id).sorted().randomElement(using: &randomNumberGenerator)`. `nonBossEnemies` is `[Enemy]` (an `Array` from static catalog). Calling `.sorted()` on an already deterministically ordered array before picking `randomElement` is redundant. Similarly, `resolveRecruitEncounter` calls `eligible.sorted(by: { $0.id < $1.id }).randomElement(using: &randomNumberGenerator)`, where `eligible` is `[MysteryEvent]` from catalog filter.
- **Fix:** Remove redundant `.sorted()` calls before `randomElement(using: &randomNumberGenerator)`.
- **LOC:** ~-2.
- **Verify:** `./Scripts/test-package.sh TrinketContent`.

### 1.2 `BattleCardCombatEngine.discardDefeatedOwnerCards` double array traversal
- **Evidence:** `Packages/BattleEngine/Sources/BattleEngine/BattleCardCombatEngine.swift:288-293` — `discardDefeatedOwnerCards` calls `context.hand.cards.filter { context.roster[$0.owner].isAlive }` to compute `survivingHand`, and then immediately iterates through `context.hand.cards` a second time with `for card in context.hand.cards where !context.roster[card.owner].isAlive` to discard defeated owner cards into the deck bottom.
- **Fix:** Consolidate into a single-pass loop over `context.hand.cards` populating `survivingHand` and discarding defeated owner cards simultaneously.
- **LOC:** ~+2/-5.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 1.3 `PreparedArtworkCache.prepareAndPin` duplicate array iteration pass
- **Evidence:** `Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift:128-137` — `prepareAndPin` executes two back-to-back `for name in unique` loops on the exact same array (`unique`) to increment pin counts and populate `pinnedImages`.
- **Fix:** Merge into a single `for name in unique` loop.
- **LOC:** ~-3.
- **Verify:** `./Scripts/test-package.sh TrinketFeatureSupport`.

---

## Phase 2 — Performance Optimizations

### 2.1 `PlayerSaveSanitizer.adjacentPath` candidate iteration efficiency
- **Evidence:** `Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveSanitizer.swift:399-420` — In `adjacentPath`, for every popped frontier node during BFS, it iterates over all `sortedNodeIDs` ($O(N)$ per popped node) checking `nodes[candidateID]` dictionary lookups and adjacency calculations.
- **Fix:** Skip visiting already-visited nodes before dictionary lookup and filter candidate lookups efficiently during BFS.
- **LOC:** ~+4/-3.
- **Verify:** `./Scripts/test-package.sh TrinketPersistence`.

### 2.2 `BattleLogReducer.entries(from:startingAt:)` allocation reduction
- **Evidence:** `Packages/BattleEngine/Sources/BattleEngine/BattleLogReducer.swift:20-22` — `result.reserveCapacity(events.count - startIndex)` reserves capacity for every event in the range, but filtering logic in `line(for:)` drops `.abilityDamage` and non-matching events (returning `nil`), leading to over-allocated arrays during high-frequency battle event streaming.
- **Fix:** Reserve capacity based on realistic non-filtered event counts when streaming log lines.
- **LOC:** ~+2/-1.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

---

## Phase 3 — Simplification & Over-Engineering Removal

### 3.1 Inline forwarder `BattleCardCombatTests.makeBattle` wrapper method
- **Evidence:** `Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:7-23` — `makeBattle(...)` is a 16-line private wrapper method inside `BattleCardCombatTests` that forwards all parameters directly to `BattleStateTestFactory.makeBattleWithAbilities(...)`.
- **Fix:** Streamline by calling `BattleStateTestFactory.makeBattleWithAbilities` directly or replacing with a concise single-line forwarding wrapper.
- **LOC:** ~-15.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 3.2 Simplify redundant return annotations in `PlaySession.swift`
- **Evidence:** `Packages/TrinketAppState/Sources/TrinketAppState/State/PlaySession.swift:96-100` — `completeActiveBattle` uses `@discardableResult` but internal callers inside `PlaySession` and surrounding mode classes never consume the return value.
- **Fix:** Remove `@discardableResult` annotation to clarify exact contract intentions.
- **LOC:** ~-1.
- **Verify:** `./Scripts/test-package.sh TrinketAppState`.

---

## Phase 4 — Test Optimization & Deduplication

### 4.1 Centralize `passiveHero`, `passiveCompanion`, and `passiveEnemy` helpers in `BattleTestFixtures`
- **Evidence:** `Packages/BattleEngine/Tests/BattleEngineTests/AffixReactionBattleTests.swift` (lines 43-49) and multiple other test files construct duplicate private wrappers `passiveCompanion()` and `passiveEnemy()`.
- **Fix:** Add `passiveHero`, `passiveCompanion`, and `passiveEnemy` static convenience methods to `BattleTestFixtures` and replace inline duplicates across `BattleEngineTests`.
- **LOC:** ~-20 across test files.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 4.2 Deduplicate `Combatant` fixture initializations in `TrinketBattleFeatureTests`
- **Evidence:** `Packages/TrinketBattleFeature/Tests/TrinketBattleFeatureTests/BattleSessionPreparationTests.swift` and `BattleSessionAutoBattleTests.swift` manually construct identical `Combatant(id: "hero", role: .hero, ...)` structs instead of using `CombatantFixtures` from `TrinketTestSupport`.
- **Fix:** Refactor test setup to use `CombatantFixtures` across `TrinketBattleFeatureTests`.
- **LOC:** ~-15 across test files.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature`.

---

## Verification Plan

### Automated Tests
- `./Scripts/test.sh unit` (Runs all package unit tests in parallel).
- `./Scripts/test-package.sh TrinketContent`
- `./Scripts/test-package.sh BattleEngine`
- `./Scripts/test-package.sh TrinketFeatureSupport`
- `./Scripts/test-package.sh TrinketPersistence`
- `./Scripts/test-package.sh TrinketAppState`
- `./Scripts/test-package.sh TrinketBattleFeature`

### Handoff Gate
- `./Scripts/handoff.sh --isolate --paths Packages/TrinketContent Packages/BattleEngine Packages/TrinketFeatureSupport Packages/TrinketPersistence Packages/TrinketAppState Packages/TrinketBattleFeature`
