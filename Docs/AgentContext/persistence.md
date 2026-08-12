# Persistence context

Use for player progression, roster, inventory, homestead, SwiftData, or CloudKit work.

`TrinketPersistence` owns the SwiftData model graph and write-through stores. `PlayerSaveRoot` owns the graph; `PlayerSaveStore` opens/configures persistence and remains a thin facade. Prefer a matching `Player*Store` slice for one concern, `PlayerHomesteadStore` for cross-slice homestead work, and value types for rules/calculations.

Campaign reward and completion **domain write policies** also live here (`BattleLoot`, `StageCompletion`, `LabyrinthCompletion`, `SpireCompletion`, `ShopPurchaseApplier`, `MysteryEffectApplier`): app sessions decide when to apply them; Persistence owns the save mutation. Save-store test harnesses live beside PersistenceTests / TrinketAppStateTests (not in `TrinketTestSupport`) so the package graph stays acyclic.

Options are deliberately separate: `OptionsStore` uses app-storage-compatible `UserDefaults`, not player-save/CloudKit state. Packages must not import app or SwiftUI feature code.

For a new store API, write a persistence test that mutates, reloads from disk, and asserts the result. Use `PersistenceTestContext`; do not test real CloudKit I/O. Run `./Scripts/test.sh style` and `./Scripts/test-package.sh TrinketPersistence`.

Read [TrinketPersistence README](../../Packages/TrinketPersistence/README.md) for the model graph. Fixture conventions: `Docs/Platform/Testing.md`. CloudKit enablement: [CloudKitPreShipChecklist.md](../Platform/CloudKitPreShipChecklist.md). Identity: [Identity.md](../Product/Identity.md).
