# TrinketPersistence Tests

Test ownership for `Packages/TrinketPersistence/Tests/TrinketPersistenceTests/`.

| Concern | Owner | Notes |
|---------|-------|-------|
| SwiftData graph | `PlayerSaveStoreTests` | Root creation, reset, seed, relaunch, and independent record updates |
| Store cleanup / duplicate roots | `PlayerSaveStoreCleanupTests` | Sidecar wipe, `resetState`, newest-primary repair |
| Graph identity | `PlayerSaveGraphIdentityTests` | Persistent IDs survive in-place updates |
| Graph repair | `PlayerSaveGraphRepairTests` | Duplicate/orphan row repair on load |
| Schema migration | `PlayerSaveSchemaMigrationTests` in `PlayerSaveStoreTests.swift` | Lightweight migration when an entity is removed |
| Save hub | `PlayerSaveStoreTests` | Direct `ModelContext` mutations plus snapshot projection |
| Snapshot validation | `PlayerSaveStoreTests` | Batch-mutation validation rollback |
| Domain actions | `PlayerHomesteadStoreTests` | Write-through cross-slice homestead actions |
| Roster / inventory state | `PlayerRosterStateTests` | Loadouts, equipment, gold (not store I/O) |
| Journey progression | `JourneyProgressTests`, `JourneyContentTests` | Unlock chain; chapter-1 structure only |
| Stage rewards | `StageRewardTests`, `HomesteadStateTests` | End-to-end grants; homestead math unit tests |

Remaining suites follow their file names.
