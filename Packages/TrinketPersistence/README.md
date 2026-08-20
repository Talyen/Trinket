# TrinketPersistence

Player save model and SwiftData stores. Graph and hub details: [persistence.md](../../Docs/AgentContext/persistence.md). DAG: [Architecture.md](../../Docs/Platform/Architecture.md).

## Conventions

- Writes go through `PlayerSaveStore.persistBatch` (Bool-returning) or `performBatchMutation` (throwing), and domain extensions on `PlayerSaveStore`
- Mutations diff `PlayerSaveSlice` values, reconcile only changed slices, and roll back only touched slices; preserve stable child-row identities
- Cross-slice domain actions live in domain extensions on `PlayerSaveStore` (e.g. `PlayerSaveStore+Homestead.swift`)
- Write-through tests: mutate → reload from disk → assert
- Store methods are `@MainActor`
- Tests use `SaveTestSupport` with `disableCloudSync: true`. The `-disable-cloud-sync` launch argument is for the app / UI tests via `AppEnvironment`, not package unit tests.

Live CloudKit stays off until [CloudKitPreShipChecklist.md](../../Docs/Platform/CloudKitPreShipChecklist.md). Save harnesses live in the `TrinketPersistenceTestSupport` target.

```sh
./Scripts/test-package.sh TrinketPersistence
```
