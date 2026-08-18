# TrinketPersistence

Player save model and SwiftData stores. Graph and hub details: [persistence.md](../../Docs/AgentContext/persistence.md). DAG: [Architecture.md](../../Docs/Platform/Architecture.md).

## Conventions

- Writes go through `PlayerSaveStore.persistBatch` (Bool-returning) or `performBatchMutation` (throwing), and slice stores such as `PlayerRosterStore` / `PlayerHomesteadStore`
- Mutations diff `PlayerSaveSlice` values, reconcile only changed slices, and roll back only touched slices; preserve stable child-row identities
- Cross-slice homestead actions live on `PlayerHomesteadStore`, not new hub methods
- Write-through tests: mutate → reload from disk → assert
- Store methods are `@MainActor`
- Tests pass `-disable-cloud-sync`

Live CloudKit stays off until [CloudKitPreShipChecklist.md](../../Docs/Platform/CloudKitPreShipChecklist.md). Save harnesses live in the `TrinketPersistenceTestSupport` target.

```sh
./Scripts/test-package.sh TrinketPersistence
```
