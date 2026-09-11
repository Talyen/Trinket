# Persistence context

Use for player progression, roster, inventory, homestead, SwiftData, or CloudKit work.

`TrinketPersistence` owns the SwiftData model graph and stores. `PlayerSaveRoot` owns the graph; `PlayerSaveStore` opens/configures persistence and provides read-only observed slices and explicit domain commands (`PlayerSaveStore+Homestead.swift`, `PlayerSaveStore+Roster.swift`, `PlayerSaveStore+ContentAccess.swift`, plus `salvageItem` in `ItemSalvage.swift` and `corruptItem` in `ItemCorruption.swift`). Prefer value types for rules/calculations. Views must use these commands or an explicit batch; assigning a save slice is not a persistence API.

Campaign reward and completion **domain write policies** also live here (`BattleLoot`, `StageCompletion`, `LabyrinthCompletion`, `SpireCompletion`, `ShopPurchaseApplier`, `MysteryEffectApplier`, `MysteryEventPinApplier`): app sessions decide when to apply them; Persistence owns the save mutation. Save-store test harnesses live in this package's `TrinketPersistenceTestSupport` target — see the package `AGENTS.md`.

`persistTransaction` returns a committed domain value, a domain rejection, or a
storage failure. It shares candidate validation, slice reconciliation, and commit
with `persistBatch` and `performBatchMutation`. Domain operations mutate a candidate
save; rejection discards it without publishing or writing. Immediate writes publish
the observed candidate only after storage succeeds. Storage failures use the existing
compensation machinery. Observable sessions apply outcomes and navigation only after commit.
Deferred mutation is an explicit `performBatchMutation(..., persistImmediately: false)`
operation, with a debounced save and a synchronous lifecycle flush; there is no
store-wide deferred-setter setting or `-defer-persistence` launch argument.

Options are deliberately separate: `OptionsStore` uses app-storage-compatible `UserDefaults`, not player-save/CloudKit state. Packages must not import app or SwiftUI feature code.

For durable store behavior, establish mutation → disk reload → assertion evidence;
existing persistence tests may suffice for a new API. Apply
[Testing.md](../Platform/Testing.md) to additions and retirement. Use `PersistenceTestContext`; do not test real CloudKit I/O. Isolate `@MainActor` on the store-opening test, not the suite, so sanitizer and domain-math tests stay parallelizable. Verification routing is owned by [Verification.md](../Platform/Verification.md).

## Focused contracts

| Concern | Canonical contract |
|---|---|
| Graph, schema, sanitization, deferred writes and failure recovery | [Storage](persistence-storage.md) |
| Rewards, claims, Shop stock, encounter identity and Homestead transactions | [Progression](persistence-progression.md) |

`agent-context.sh` selects known domain paths; store hubs, tests and unknown paths
receive both contracts. Follow the storage contract when a domain change touches
graph reconciliation or serialization. Current-data validation and corruption
recovery remain required; schema changes must follow the storage contract.

CloudKit enablement: [CloudKit checklist](../Platform/CloudKitPreShipChecklist.md).
Identity: [Identity](../Product/Identity.md).
