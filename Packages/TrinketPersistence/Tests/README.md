# TrinketPersistence Tests

Test ownership for `Packages/TrinketPersistence/Tests/TrinketPersistenceTests/`.

| Concern | Owner | Notes |
|---------|-------|-------|
| SwiftData graph | `PlayerSaveStoreTests` | Root creation, reset, seed, relaunch, and independent record updates |
| Save hub | `PlayerSaveStoreTests` | Direct `ModelContext` mutations plus snapshot projection |
| Snapshot validation | `PlayerSaveStoreTests` | Invalid state repair for calculation DTOs |
| Domain actions | `PlayerHomesteadStoreTests` | Write-through cross-slice homestead actions |
| Roster / inventory state | `PlayerRosterStateTests` | Loadouts, equipment, gold (not store I/O) |
| Journey progression | `JourneyProgressTests`, `JourneyContentTests` | Unlock chain; chapter-1 structure only |
| Stage rewards | `StageRewardTests`, `HomesteadStateTests` | End-to-end grants; homestead math unit tests |

Remaining suites follow their file names.
