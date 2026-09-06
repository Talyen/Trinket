# TrinketPersistence

Player save model and SwiftData stores. Graph and hub details: [persistence.md](../../Docs/AgentContext/persistence.md). DAG: [Architecture.md](../../Docs/Platform/Architecture.md).

## Conventions

- Writes go through `PlayerSaveStore.persistBatch` (Bool-returning) or `performBatchMutation` (throwing), and domain extensions on `PlayerSaveStore`
- Mutations diff `PlayerSaveSlice` values and reconcile only changed slices, preserving retained child-row identities; failed writes use snapshot compensation as defined in the [persistence guide](../../Docs/AgentContext/persistence.md)
- Cross-slice domain actions live in domain extensions on `PlayerSaveStore` (e.g. `PlayerSaveStore+Homestead.swift`)
- Store methods are `@MainActor`
- Tests use `SaveTestSupport` with `disableCloudSync: true`; write-through tests follow the [Testing.md](../../Docs/Platform/Testing.md) mutate → reload rubric. The `-disable-cloud-sync` launch argument is for the app / UI tests via `AppEnvironment`, not package unit tests.

Live CloudKit stays off until [CloudKitPreShipChecklist.md](../../Docs/Platform/CloudKitPreShipChecklist.md).

```sh
./Scripts/test-package.sh TrinketPersistence
```
