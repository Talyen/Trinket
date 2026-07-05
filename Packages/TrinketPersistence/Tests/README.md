# TrinketPersistence Tests

Test ownership for `Packages/TrinketPersistence/Tests/TrinketPersistenceTests/`.

| Concern | Owner | Notes |
|---------|-------|-------|
| File I/O + migration | `PlayerSaveFileStoreTests`, `PlayerSaveMigrationTests` | Round-trip, backup, schema chain |
| Save hub | `PlayerSaveStoreTests`, `PlayerSaveStoreBatchTests` | Persist, reset, batch mutation |
| Sanitizer / merger | `PlayerSaveSanitizerTests`, `PlayerSaveMergerTests` | Invalid state repair, field merge |
| Sync lifecycle | `PlayerSaveSyncCoordinatorTests` | Mock sync; includes upload conflict |
| Reconcile authority | `PlayerSaveSessionAuthorityTests` | Timestamp / session generation |
| Domain stores | `Player*StoreTests` | Write-through slice APIs |
| Roster / inventory state | `PlayerRosterStateTests` | Loadouts, equipment, gold (not store I/O) |
| Journey progression | `JourneyProgressTests`, `JourneyContentTests` | Unlock chain; chapter-1 structure only |
| Stage rewards | `StageRewardTests`, `HomesteadStateTests` | End-to-end grants; homestead math unit tests |
| Saved effect encoding | `SavedEffectRoundtripTests` | Cross-package contract with `TrinketCore` |

| Sync factory | `PlayerSaveSyncFactoryTests` | CloudKit entitlement gating vs local-only |
