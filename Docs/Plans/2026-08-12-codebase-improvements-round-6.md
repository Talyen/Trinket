# Codebase Improvement Plan — Round 6 (Bugs, Performance, Simplification, Tests)

Date: 2026-08-12  
Status: Proposed execution plan  
Scope: Whole-repo exploration for confirmed improvement candidates across four categories (Bugs, Performance, Simplification, Tests). Every item was verified by inspecting source code before inclusion.

Guiding rules applied:
- Deliver the smallest change that fully satisfies the requirement.
- Prefer delete → reuse → simplify → parameterize.
- Path-scoped verification with `--isolate` before handoff.

---

## Phase 1 — Correctness & Code Safety (Bugs)

### 1.1 `ItemGenerator.weightedSample` side-effecting predicate in `firstIndex(where:)`
- **Evidence:** [`ItemGenerator.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketContent/Sources/TrinketContent/ItemGenerator.swift#L88-L93) — In `weightedSample`, `var roll` is mutated inside the predicate closure passed to `pool.firstIndex { definition in roll -= adjustedWeight(...); return roll <= 0 } ?? 0`. Mutating captured local state inside standard library collection predicates is non-idiomatic and fragile under closure re-evaluation. Additionally, the fallback `?? 0` silently forces index 0 if any unexpected roll boundary condition occurs.
- **Fix:** Replace the side-effecting `firstIndex(where:)` call with a standard linear loop (`for (index, definition) in pool.enumerated()`) that inspects and decrements `roll` without state mutation inside higher-order predicates, eliminating the `?? 0` fallback.
- **LOC:** ~+5/-4.
- **Verify:** `./Scripts/test-package.sh TrinketContent` & `./Scripts/test-package.sh TrinketPersistence`.

---

## Phase 2 — Performance Optimizations

### 2.1 `LabyrinthGenerator.gridPositions` combinatorial allocation churn
- **Evidence:** [`LabyrinthGenerator.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketContent/Sources/TrinketContent/LabyrinthGenerator.swift#L202-L215) — In `gridPositions`, `combinations(of: middleCandidates, choosing: nodeCount - 2)` pre-allocates up to $\binom{20}{7} = 77,520$ array combinations into `middleSets` and shuffles them upfront with `middleSets.shuffle(using: &rng)`. This allocates over 500,000 grid position objects in memory per depth try during floor generation and save migration, even though the search loop terminates immediately upon finding the first valid layout (typically within the first few candidates).
- **Fix:** Replace full upfront combinatorial array generation and shuffling with bounded random sampling using `rng` (sampling random candidate subsets iteratively), reducing memory footprint from $O(\binom{N}{K})$ to $O(1)$ and speeding up map layout generation.
- **LOC:** ~+8/-6.
- **Verify:** `./Scripts/test-package.sh TrinketContent` & `./Scripts/test-package.sh TrinketPersistence` & `./Scripts/test-package.sh TrinketAppState`.

---

## Phase 3 — Simplification & Over-Engineering Removal

### 3.1 `BattleCardCombatEngine.drawCardsBalanced` redundant hand count recalculations
- **Evidence:** [`BattleCardCombatEngine.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Sources/BattleEngine/BattleCardCombatEngine.swift#L268-L274) — `drawCardsBalanced` compares candidates using `candidates.min` where the comparator closure evaluates `context.hand.cards.count { $0.owner == lhs }` and `context.hand.cards.count { $0.owner == rhs }` on every candidate comparison step inside the `while true` loop.
- **Fix:** Compute hero and companion hand counts once per step before candidate evaluation or simplify candidate selection for the two party roles directly.
- **LOC:** ~+4/-6.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

---

## Phase 4 — Test Optimization & Deduplication

### 4.1 Centralize dummy combatant creation in `BattleEngineTests`
- **Evidence:** [`EffectHandlersTurnTests.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersTurnTests.swift) and [`EffectHandlersApplyTests.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyTests.swift) manually instantiate inline `Combatant(id: "hero", name: "Hero", ...)` instead of using `BattleStateTestFactory.passiveHero()`, `passiveCompanion()`, or `passiveEnemy()`.
- **Fix:** Refactor test setups to use `BattleStateTestFactory` static helpers (`passiveHero()`, `passiveCompanion()`, `passiveEnemy()`).
- **LOC:** ~-15 across test files.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

---

## Verification Plan

### Automated Tests
- `./Scripts/test.sh unit`
- `./Scripts/test-package.sh TrinketContent`
- `./Scripts/test-package.sh TrinketPersistence`
- `./Scripts/test-package.sh BattleEngine`
- `./Scripts/test-package.sh TrinketAppState`

### Handoff Gate
- `./Scripts/handoff.sh --isolate --paths Packages/TrinketContent Packages/TrinketPersistence Packages/BattleEngine Packages/TrinketAppState`
