# Persistence context

Use for player progression, roster, inventory, homestead, SwiftData, or CloudKit work.

## Ownership

`TrinketPersistence` owns the SwiftData model graph and stores. `PlayerSaveRoot` owns the graph; `PlayerSaveStore` opens/configures persistence and provides read-only observed slices and explicit domain commands (`PlayerSaveStore+Homestead.swift`, `PlayerSaveStore+Roster.swift`, `PlayerSaveStore+ContentAccess.swift`, plus `salvageItem` in `ItemSalvage.swift` and `corruptItem` in `ItemCorruption.swift`). Prefer value types for rules/calculations. Views and AppState use domain commands; unrestricted save/roster mutation closures are internal to Persistence. Assigning a save slice is not a persistence API.

Campaign reward and completion **domain write policies** also live here (`StageCompletion`, `LabyrinthCompletion`, `SpireCompletion`, `ShopPurchaseApplier`, `MysteryEffectApplier`): app sessions decide when to apply them; Persistence owns the save mutation. Save-store test harnesses live in this package's `TrinketPersistenceTestSupport` target — see the package `AGENTS.md`.

Commands mutate candidates and publish only after durable acceptance; rejection
publishes nothing. App sessions apply navigation and outcomes only after commit.
Read [transaction details](#transactions) when changing mutation, receipts,
reconciliation, or recovery; serialized changes also need the storage contract.

## Transactions

Domain commands return a committed value, a domain rejection, or a storage failure.
`SaveTransactionResult.persistFailed` carries that operation's typed error, so callers
can distinguish transient writes from validation failures without reading shared diagnostics.
The internal `persistTransaction`, `persistBatch`, and `performBatchMutation` share
candidate validation, slice reconciliation, and commit. Every candidate captures
the store's in-memory commit revision before domain work; a nested durable command
or reset makes that candidate obsolete. Commit rejects it before graph or journal
writes, preserving the newer progress. The revision is transient and does not
change serialized saves.

Economic commands use `persistAction` or ordered `SaveEconomicMutation.resolve`
calls. Each action freezes complete before/after values, semantic kind, and claim;
commit derives receipts and validates complete Gold/material/XP/fractional coverage,
including with cloud disabled. Non-economic commands use empty receipts and reject
economic edits. Sanitation and Library reconciliation finalize the action before
journaling. AppState supplies neither candidate mutations nor receipts; independent
receipt callbacks remain Debug-only legacy fixtures through `@testable` access.
[Journal replay](persistence-storage.md#journal-and-economic-replay) owns action
ordering, coupled effects, and duplicate decisions.

Rejection discards the candidate without writing or publishing. Accepted writes
publish only after the graph or recovery file is durable; sessions then apply
navigation and outcomes, keeping technical save errors internal. [Storage recovery](persistence-storage.md#durable-acceptance-and-recovery)
owns compensation and silent retries. `flushPendingPersistence` retries an already
accepted recovery-file save at lifecycle/sync checkpoints, never an uncommitted edit.

Roster edits carry combatant, ability, and physical item IDs, never caller-owned
catalog or Inventory snapshots. Content owns `PlayerRosterState` and its candidate-value
rules in `Roster/RosterEdits.swift`; they resolve those IDs against current content,
unlocks, purchase access, and the inventory supplied by Persistence inside the
transaction. Persistence owns admission, hydration/migration, and durable publication.
Loadout, party, and talent commands return `RosterEditResult`;
only `persistenceFailed` schedules a save retry. Unavailable intents do not write
or silently select a fallback; save hydration still repairs older data.

Options are deliberately separate: `OptionsStore` uses app-storage-compatible `UserDefaults`, not player-save/CloudKit state. Packages must not import app or SwiftUI feature code.

For durable store behavior, establish mutation → disk reload → assertion evidence;
existing persistence tests may suffice for a new API. Apply
[Testing.md](../Platform/Testing.md) to additions and retirement. Use `PersistenceTestContext`; do not test real CloudKit I/O. Isolate `@MainActor` on the store-opening test, not the suite, so sanitizer and domain-math tests stay parallelizable. Verification routing is owned by [Verification.md](../Platform/Verification.md).

## Focused contracts

| Concern | Canonical contract |
|---|---|
| Graph, schema, sanitization and failure recovery | [Storage](persistence-storage.md) |
| Rewards, claims, Shop stock, encounter identity and Homestead transactions | [Progression](persistence-progression.md) |

The scoped briefing lists both contracts for this owner; leaf renames do not change
that guidance. Read relevant sections and follow the
storage contract when a domain change touches
graph reconciliation or serialization. Current-data validation and corruption
recovery remain required; schema changes must follow the storage contract.

SwiftData remains local; explicit complete-save CloudKit synchronization is owned
by Persistence, with lifecycle polling, account events, and session invalidation
owned by AppState. CloudKit enablement: [CloudKit checklist](../Platform/CloudKitPreShipChecklist.md).
AppState installs account and external-progress hooks even when sync is initially
unavailable. Foreground polling resolves the store's current sync capability on
each pass, so durable-storage recovery can enable synchronization in the same session.
Identity: [Identity](../Product/Identity.md).
