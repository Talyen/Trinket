# TrinketPersistence Tests

Test ownership for `Packages/TrinketPersistence/Tests/TrinketPersistenceTests/`.
Tests are grouped in `Storage/`, `Cloud/`, `Progression/`, `Encounters/`, and
`Inventory/` according to the behavior they prove.

Store I/O tests isolate `@MainActor` on the test that opens `PlayerSaveStore`, not the suite. Value-type sanitizer, loot, and homestead math stay off the main actor so they can run in parallel. Write-through proofs still follow the mutate → reload-from-disk rubric in [Testing.md](../../../Docs/Platform/Testing.md).

## Ownership boundaries

| Concern | Boundary and starting points |
|---|---|
| Durable writes, reset, recovery and retries | `Storage/`: `PlayerSaveStoreTests`, `PendingSaveRecoveryTests`; prove accepted writes survive reload and rejected writes preserve prior progress. |
| Graph identity, schema and repair | `Storage/`: identity/repair/sanitizer suites; preserve in-place relationships, supported-save migration, world seeds and starter selection. |
| Cloud merge, outbox and transport | `Cloud/`: `CloudSaveMerge*Tests`, `CloudSaveSyncTests`; use pure values or fake transport, including account/reset isolation, interrupted requests, and reload. No live CloudKit I/O. |
| Saved progression and rewards | `Progression/`: stage reward, talent and loot suites; prove saved admission, claims, captured levels and once-only settlement. Pure roll policy belongs to Content. |
| Encounter lifecycle | `Encounters/`: Campaign, Spires, Shop, Mystery, Contracts, Voyage and Labyrinth suites; prove pinned offers, stale/duplicate rejection, rollback, and unreadable-payload preservation. |
| Inventory and roster commands | `Inventory/`: `RosterEditPersistenceTests`, Salvage/Corruption and item-resolution suites; prove current-input admission, compensation, compatibility and reload. Pure edit/yield rules belong to Content. |
| Homestead save integration | `PlayerHomesteadStoreTests`, `HomesteadStateTests`; prove saved collection/build/craft settlement and overflow. Production timing and affordability math belong to Content. |

The domain directories contain the complete suite inventory. Extend the existing
assertion owner; a suite name alone does not establish coverage. Retain the narrow
[Content/store split](../../TrinketContent/Tests/README.md) when moving rules.

Harnesses: `Support/PersistenceTestContext.swift` (fresh temp dir per test) and `TrinketPersistenceTestSupport.SaveTestSupport` (`writeRoot`, `makeSave`, `makeSideContext`, `makeGeneratedItem`, store factory).

Generated save-recovery and Voyage replay tests use fixed seed arguments; the
reported seed reproduces the complete input. Ordinary package CI runs 64 and 32
cases respectively. The manually dispatched **Generated save recovery exploration**
workflow runs 512 of each and verifies the executed argument counts. It retains
test diagnostics so a failing seed can be promoted to a focused regression.
