# Persistence context

Use for player progression, roster, inventory, homestead, SwiftData, or CloudKit work.

`TrinketPersistence` owns the SwiftData model graph and write-through stores. `PlayerSaveRoot` owns the graph; `PlayerSaveStore` opens/configures persistence and provides write-through slice properties and domain extensions (`PlayerSaveStore+Homestead.swift`, `PlayerSaveStore+Roster.swift`). Prefer value types for rules/calculations.

Reads use an in-memory observed projection; load/repair sanitizes `root.toPlayerSave()` from the SwiftData graph. Semantic `PlayerSave.currentSchemaVersion` is independent of the SwiftData `Schema.Version(1, 0, 0)` — field-shape migrations live in sanitizer/mapping. `PlayerSaveSchema.Version(1,0,0)` is the SwiftData migration version; `PlayerSave.currentSchemaVersion` is the value-layer version — bumping one does not imply bumping the other until a real SwiftData migration ships. Slice writes expand through `PlayerSaveSlice.sanitizeTargets`: inventory also sanitizes roster (equipped items must exist). Labyrinth sanitize runs on labyrinth mutations and full load, not on every inventory or roster write; recruit eligibility is applied when a map is generated.

Labyrinth's map is a JSON blob (`LabyrinthProgressModel.mapPayload`) while roster/inventory/homestead are normalized child tables — intentional trade-off for spatial graph queries; don't normalize the labyrinth without measuring encode cost.

Campaign reward and completion **domain write policies** also live here (`BattleLoot`, `StageCompletion`, `LabyrinthCompletion`, `SpireCompletion`, `ShopPurchaseApplier`, `MysteryEffectApplier`, `MysteryEventPinApplier`): app sessions decide when to apply them; Persistence owns the save mutation. Save-store test harnesses live in this package's `TrinketPersistenceTestSupport` target — see the package `AGENTS.md`.

Options are deliberately separate: `OptionsStore` uses app-storage-compatible `UserDefaults`, not player-save/CloudKit state. Packages must not import app or SwiftUI feature code.

Failed writes restore the pre-mutation value snapshot into the affected graph slices
and observed projection. This compensation stays unsaved until a later successful
write; recovery does not call `ModelContext.rollback()` because restoring deleted
relationship rows can crash SwiftData on the iOS 27 simulator. An immediate failure
preserves earlier deferred changes, while a failed deferred flush restores its
last persisted snapshot. Full resets compensate the complete graph. Reload tests
must also prove that a subsequent successful write preserves the recovered values.

For a new store API, write a persistence test that mutates, reloads from disk, and asserts the result. Use `PersistenceTestContext`; do not test real CloudKit I/O. Isolate `@MainActor` on the store-opening test, not the suite, so sanitizer and domain-math tests stay parallelizable. Verification routing is owned by [Verification.md](../Platform/Verification.md).

Read [TrinketPersistence README](../../Packages/TrinketPersistence/README.md) for the model graph. Fixture conventions: `Docs/Platform/Testing.md`. CloudKit enablement: [CloudKitPreShipChecklist.md](../Platform/CloudKitPreShipChecklist.md). Identity: [Identity.md](../Product/Identity.md).
