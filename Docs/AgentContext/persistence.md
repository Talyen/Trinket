# Persistence context

Use for player progression, roster, inventory, homestead, SwiftData, or CloudKit work.

`TrinketPersistence` owns the SwiftData model graph and stores. `PlayerSaveRoot` owns the graph; `PlayerSaveStore` opens/configures persistence and provides read-only observed slices and explicit domain commands (`PlayerSaveStore+Homestead.swift`, `PlayerSaveStore+Roster.swift`, `PlayerSaveStore+ContentAccess.swift`, plus `salvageItem` in `ItemSalvage.swift` and `corruptItem` in `ItemCorruption.swift`). Prefer value types for rules/calculations. Views must use these commands or an explicit batch; assigning a save slice is not a persistence API.

Reads use an in-memory observed projection; load/repair sanitizes `root.toPlayerSave()` from the SwiftData graph. `PlayerSave.currentSchemaVersion` versions the value-layer payload and its sanitizer/mapping migrations independently of the SwiftData migration version declared by `PlayerSaveSchema`; bumping one does not imply bumping the other. Slice writes expand through `PlayerSaveSlice.sanitizeTargets`: inventory also sanitizes roster (equipped items must exist), and labyrinth also sanitizes roster (recruit eligibility feeds map healing). Labyrinth sanitize runs on labyrinth mutations and full load, not on every inventory or roster write; recruit eligibility is applied when a map is generated.

Roster sanitization accepts current catalog IDs and applies [Core talent repair](../../Packages/TrinketCore/README.md).

Trinket has no released player saves or production CloudKit schema. Historical
development-save migrations and retired identifier aliases have been removed;
the current value schema identifier is unchanged. Unsupported value schemas are
rejected without rewriting their progress. Unsupported Labyrinth map payloads use
the existing unreadable-map recovery path, without translating historical floor
progress. Current-data validation, relationship repair, and corruption recovery
remain required. Once saves ship, preserve or migrate them before changing their
schema or serialized identifiers.

Labyrinth's map is a JSON blob (`LabyrinthProgressModel.mapPayload`) while roster/inventory/homestead are normalized child tables — intentional trade-off for spatial graph queries; don't normalize the labyrinth without measuring encode cost.

Campaign reward and completion **domain write policies** also live here (`BattleLoot`, `StageCompletion`, `LabyrinthCompletion`, `SpireCompletion`, `ShopPurchaseApplier`, `MysteryEffectApplier`, `MysteryEventPinApplier`): app sessions decide when to apply them; Persistence owns the save mutation. Save-store test harnesses live in this package's `TrinketPersistenceTestSupport` target — see the package `AGENTS.md`.

Battle launch captures reward quantities, recipients, bonuses, and Gold-overflow
XP in `BattleRewardPlan`. `RewardSettlementInputs` projects wallet reservations
and recipient progression at a recorded production date. Content's pure settlement
produces `BattleRewardSettlement`; the same value drives the reveal and completion.
A positive net Gold award that cannot fit replaces all Gold gains with XP while
retaining any generic battle-spending field for compatibility. Current combat
content does not produce battle spending. Mystery bonuses use the same capacity
policy. Completion revalidates the recorded
snapshot and rejects stale settlements before any mode completion; the UI refreshes
its reveal before another claim. Application uses the recorded production date so
passive accrual cannot silently shrink a displayed award. Unprepared rewards use
the same settlement path. Modes retain their existing one-time claim ownership.

`persistTransaction` returns a committed domain value, a domain rejection, or a
storage failure. It shares candidate validation, slice reconciliation, and commit
with `persistBatch` and `performBatchMutation`. Domain operations mutate a candidate
save; rejection discards it without publishing or writing. Immediate writes publish
the observed candidate only after storage succeeds. Storage failures use the existing
compensation machinery. Observable sessions apply outcomes and navigation only after commit.
Deferred mutation is an explicit `performBatchMutation(..., persistImmediately: false)`
operation, with a debounced save and a synchronous lifecycle flush; there is no
store-wide deferred-setter setting or `-defer-persistence` launch argument.
`MysteryEncounterResolution` owns choice effects and progress together, including
required item/unlock validation; a secondary reward cannot turn an unavailable
headline reward into a successful choice. Deliberate leave is an explicit outcome.

`EncounterIdentity` scopes Journey stages and Labyrinth nodes to their world seed
and save generation. Shop offers are pinned on first opening; stock and purchased
offer IDs live in the Journey stage payload or Labyrinth node payload. Stock
survives inventory removal and reload; singleton ownership is a separate check.
`ShopPurchaseApplier` accepts an offer ID and reads saved stock, including its price.
Views and commands share its availability query. Never infer claims from inventory
ID prefixes or session flags. Homestead build commands require the displayed target
tier and validate that tier inside the transaction.

Options are deliberately separate: `OptionsStore` uses app-storage-compatible `UserDefaults`, not player-save/CloudKit state. Packages must not import app or SwiftUI feature code.

Failed writes restore the pre-mutation value snapshot into the affected graph slices
and observed projection. This compensation stays unsaved until a later successful
write; recovery does not call `ModelContext.rollback()` because restoring deleted
relationship rows can crash SwiftData on the iOS 27 simulator. An immediate failure
preserves earlier deferred changes, while a failed deferred flush restores its
last persisted snapshot. Full resets compensate the complete graph. Reload tests
must also prove that a subsequent successful write preserves the recovered values.

For durable store behavior, establish mutation → disk reload → assertion evidence;
existing persistence tests may suffice for a new API. Apply
[Testing.md](../Platform/Testing.md) to additions and retirement. Use `PersistenceTestContext`; do not test real CloudKit I/O. Isolate `@MainActor` on the store-opening test, not the suite, so sanitizer and domain-math tests stay parallelizable. Verification routing is owned by [Verification.md](../Platform/Verification.md).

Read [TrinketPersistence README](../../Packages/TrinketPersistence/README.md) for the model graph. Fixture conventions: `Docs/Platform/Testing.md`. CloudKit enablement: [CloudKitPreShipChecklist.md](../Platform/CloudKitPreShipChecklist.md). Identity: [Identity.md](../Product/Identity.md).
