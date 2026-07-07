# Behavior Hardening Audit

Goal: Strengthen correctness at module boundaries — Swift concurrency, persistence, state machines, and error handling.

## Targets

- `rg -n 'async|await|Task\.|ContinuousClock|SuspendingClock|withTaskGroup|withDiscardingTaskGroup|async\s+let' --type swift -g '!*Tests*' -g '!**/Generated/*'` — flag every async and timing boundary
- `rg -n 'try!|try?' --type swift -g '!*Tests*'` — target 0 in non-test, non-generated source
- `rg -n 'fatalError|precondition|assertionFailure' --type swift -g '!*Tests*' -g '!**/Generated/*'` — review each; target near 0 outside package inits
- `rg -n 'modifiedAt|lastSynced|merge|reconcile|cloudKitContainerIdentifier' --type swift -g '!*Tests*'` — CloudKit and local save state boundaries

## Checks

### Null/empty/optional paths at module boundaries

- Every `init?(from:)` decoder validates required keys; do not rely on implicit defaults for critical save fields
- `Codable` structs with optional fields — verify that nil is a valid semantic state, not a forgotten migration path
- `as?` + `guard`/`if let` for all downcasts (see [TypeSafetyAudit.md](file:///Users/ryanmcintire/Documents/Trinket/Docs/Audits/TypeSafetyAudit.md)); target zero `as!`
- At persistence boundaries, validate decoded values (range-check IDs, stage numbers, counts) — a corrupt save should fail decode, not silently produce invalid game state
- UI test launch args (`-completed-stages`, `-launch-screen`) parse through [AppEnvironment.swift](file:///Users/ryanmcintire/Documents/Trinket/Trinket/Shared/AppEnvironment.swift) — invalid args should fall back to defaults gracefully, not crash

### State transitions are idempotent

- [PlayerSaveStore.swift](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift) — SwiftData automatic synchronization merges and replicates fields natively. Verify mutations to the model graph always update `modifiedAt` cleanly and sanitize inputs using [PlayerSaveSanitizer.swift](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveSanitizer.swift).
- [BattleSession.swift](file:///Users/ryanmcintire/Documents/Trinket/Trinket/State/BattleSession.swift) — stage completion should be idempotent: tapping "Continue" twice must not double-grant rewards.
- `PlayerHomesteadState.adjustedMaterialRewards` — multiple calls with the same stage data must return the same result.
- Debounced save writes in [PlayerSaveStore.swift](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift) — rapid mutations should coalesce correctly without producing duplicate, stale, or out-of-order writes.
- SwiftUI `task` modifiers — ensure cancellation and re-entrance: a view that appears, disappears, and reappears must not leak concurrent operations.

### No swallowed errors

- `Task { … }` blocks at the UI layer should at minimum log failures; silent `try?` in orchestration code (state transitions, battle outcome, save) is suspect
- [PlayerSaveStore.swift](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift) writes — failure must surface (sets `lastPersistenceError`); silent failure on save is data loss
- CloudKit sync replication — watch diagnostics in output when debugging sync; SwiftData-managed CloudKit integration errors should be surfaced or handled gracefully (offline fallback)
- `AVFoundation` playback errors — `try?` is acceptable in audio (playback failure is non-fatal), but should log
- Store loading failures — if a save store is corrupt, fall back to default/in-memory state cleanly rather than crashing; log the original error

### Architectural invariants in changed code

- Packages must not import `Trinket` app code (verified by [check-module-boundaries.sh](file:///Users/ryanmcintire/Documents/Trinket/Scripts/check-module-boundaries.sh))
- `TrinketDesignSystem` must not import `BattleEngine` or `TrinketContent` (depends on `TrinketCore` only)
- `BattleEngine` and `TrinketPersistence` are siblings — must not import each other
- `Effects` are value-type structs conforming to `BattleEffectHandler`; verify new effect kinds are registered in `EffectHandlers.all`
- UI tests: `accessibilityIdentifier` like `"Stage 1-1 Node"`, not localized strings or enum raw values

### Edge cases covered by existing tests

- Before adding new tests, check if an existing test already covers the edge case (especially in `BattleEngineTests` and `TrinketPersistenceTests`)
- Add tests only when fixing a gap — prefer strong existing tests over many weak new ones
- Use `BattleStateTestFactory.makeBattle(seed: 0)` for deterministic battle edge cases
- Store test edge cases: empty save, partial save (migration), concurrent read/write, corrupted JSON

