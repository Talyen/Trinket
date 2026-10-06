# Persistence context

Use for player progression, roster, inventory, homestead, SwiftData, or CloudKit work.

`TrinketPersistence` owns the SwiftData model graph and stores. `PlayerSaveRoot` owns the graph; `PlayerSaveStore` opens/configures persistence and provides read-only observed slices and explicit domain commands (`PlayerSaveStore+Homestead.swift`, `PlayerSaveStore+Roster.swift`, `PlayerSaveStore+ContentAccess.swift`, plus `salvageItem` in `ItemSalvage.swift` and `corruptItem` in `ItemCorruption.swift`). Prefer value types for rules/calculations. Views and AppState use domain commands; unrestricted save/roster mutation closures are internal to Persistence. Assigning a save slice is not a persistence API.

Campaign reward and completion **domain write policies** also live here (`BattleLoot`, `StageCompletion`, `LabyrinthCompletion`, `SpireCompletion`, `ShopPurchaseApplier`, `MysteryEffectApplier`, `MysteryEventPinApplier`): app sessions decide when to apply them; Persistence owns the save mutation. Save-store test harnesses live in this package's `TrinketPersistenceTestSupport` target — see the package `AGENTS.md`.

Domain commands return a committed value, a domain rejection, or a storage failure.
The internal `persistTransaction`, `persistBatch`, and `performBatchMutation` share
candidate validation, slice reconciliation, and commit. Economic commands collect
required `SaveEconomicReceipt` values in a synchronous `SaveEconomicMutation`;
AppState neither mutates the candidate nor forwards receipts. Before any graph or
journal write, commit verifies that receipt replay accounts for the candidate's
Gold, materials, XP and fractional balances. Missing or partial effects reject the
whole transaction even when cloud sync is disabled. Receipts and game progress
share the same durable commit and compensation. Non-economic commands retain
save-only transactions; test fixtures may exercise legacy batches through
`@testable import TrinketPersistence`.
Domain operations mutate a candidate
save; rejection discards it without publishing or writing. Immediate writes publish
the observed candidate only after the graph or durable recovery file accepts it.
Total write failures use compensation and silent action retries, as described in
[storage recovery](persistence-storage.md). Observable sessions apply outcomes and
navigation only after commit; they do not show technical save-error alerts.
Deferred mutation is an internal `performBatchMutation(..., persistImmediately: false)`
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

`agent-context.sh` suggests references for known domain paths; store hubs, tests
and unknown paths list both for discovery. Read relevant sections and follow the
storage contract when a domain change touches
graph reconciliation or serialization. Current-data validation and corruption
recovery remain required; schema changes must follow the storage contract.

SwiftData remains local; explicit complete-save CloudKit synchronization is owned
by Persistence, with lifecycle polling, account events, and session invalidation
owned by AppState. CloudKit enablement: [CloudKit checklist](../Platform/CloudKitPreShipChecklist.md).
Identity: [Identity](../Product/Identity.md).
