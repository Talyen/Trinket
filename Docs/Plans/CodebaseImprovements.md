# Codebase Improvement Plan: Performance Indexing & DefensePoolEngine Simplification

## Context & Objectives

During codebase exploration across packages (`BattleEngine`, `TrinketContent`, `TrinketPersistence`, `TrinketBattleFeature`, `TrinketAppState`), two distinct improvements were identified:
1. **Performance Optimization**: `GameContent.enemy(matching:)` performs a linear array scan (`enemies.first { $0.id == id }`) on every call. Combat fight pacing (`FightPacing.isBossEnemy(in:)` / `BattleState.paced(...)`) invokes this lookup repeatedly during every combat tick (damage, block, heal, and control meter updates) across player actions, enemy actions, DoT ticks, and high-volume balance sweeps.
2. **Code Simplification**: `DefensePoolEngine.Pool` in `BattleEngine` is an over-engineered single-case enum (`case block`) with ~50 lines of boilerplate mapping/dispatch methods and single-case switches. Collapsing this abstraction simplifies the block/defense subsystem, aligning with Trinket's change discipline: *delete → reuse → simplify locally*.

---

## Improvement 1: Constant-Time \(O(1)\) Enemy Indexing in `GameContent`

### Problem
- In [`GameContent+Roster.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketContent/Sources/TrinketContent/GameContent+Roster.swift#L9-L11):
  ```swift
  static func enemy(matching id: String) -> Enemy? {
      enemies.first { $0.id == id }
  }
  ```
- `enemies` is an array of 15+ enemies generated in [`GameContentEnemies.generated.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift).
- Every time `BattleState.paced(...)` evaluates combat magnitudes, it calls `FightPacing.isBossEnemy(in: self)`, which calls `GameContent.enemy(matching: context.enemy.id)?.isBoss`.
- In battle simulations, DoT evaluations, and balance sweeps (running thousands of battles), this causes repeated unnecessary string array scans.

### Proposed Solution
1. In `Packages/TrinketContent/Sources/TrinketContent/GameContentEnemies.swift` (or `GameContent+Roster.swift`):
   - Build an indexed dictionary `enemiesByID: [String: Enemy] = Dictionary(uniqueKeysWithValues: enemies.map { ($0.id, $0) })`.
2. Update `GameContent.enemy(matching id: String) -> Enemy?` to query `enemiesByID[id]`.
3. Add unit test verification in `Packages/TrinketContent/Tests/TrinketContentTests/EnemyCatalogTests.swift` ensuring every enemy ID resolves in \(O(1)\) lookup matching the array contents.

---

## Improvement 2: Simplify Over-Engineered `DefensePoolEngine.Pool` Enum

### Problem
- In [`DefensePoolEngine.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Sources/BattleEngine/DefensePoolEngine.swift#L6-L62):
  - `package enum Pool: Sendable { case block ... }` is a 1-case enum.
  - It defines 8 boilerplate methods/properties with 1-case `switch` statements (`effectKind`, `appliedEffectKind`, `defaultKeyword`, `matches`, `points`, `decodeGain`, `makeEffect`, `withAmount`).
  - Methods like `points(in:pool:)`, `add(_:pool:to:...)`, and `set(_:pool:on:...)` require passing `pool: .block` at call sites.
- All callers in production (`DefensiveBuffHandlers.swift`, `EnemyTraitEngine.swift`, `DamagePipelineResolutionSteps.swift`) only ever pass `.block`.

### Proposed Solution
1. Remove `DefensePoolEngine.Pool` enum.
2. Directly implement clean block helpers on `DefensePoolEngine`:
   - `package static func blockPoints(in effects: [ActiveEffect]) -> Int`
   - `package static func addBlock(_ amount: Int, to target: Combatant, keyword: Keyword = .block, sourceActorID: String? = nil, in context: inout BattleState) -> Int`
   - `package static func setBlock(_ amount: Int, on target: Combatant, in context: inout BattleState)`
   - `package static func decayBlockAtEndOfRound(on target: Combatant, in context: inout BattleState)`
   - `package static func halveBlock(on target: Combatant, in context: inout BattleState) -> Bool`
3. Update callers in `BattleEngine`:
   - [`DefensiveBuffHandlers.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Sources/BattleEngine/EffectHandlers/DefensiveBuffHandlers.swift)
   - [`EnemyTraitEngine.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Sources/BattleEngine/EnemyTraitEngine.swift)
   - [`DamagePipelineResolutionSteps.swift`](file:///Users/ryanmcintire/Documents/Trinket/Packages/BattleEngine/Sources/BattleEngine/DamagePipelineResolutionSteps.swift)
4. Ensure all unit tests in `BattleEngineTests` pass without regressions.

---

## Verification Plan

### Automated Tests
- Run package tests for modified packages:
  - `./Scripts/test-package.sh TrinketContent`
  - `./Scripts/test-package.sh BattleEngine`
- Run full unit tests:
  - `./Scripts/test.sh unit`
- Run linting and style checks:
  - `./Scripts/lint.sh`
