# TrinketPersistence

Player save model and SwiftData stores. Graph and hub details: [persistence.md](../../Docs/AgentContext/persistence.md). DAG: [Architecture.md](../../Docs/Platform/Architecture.md).

## Conventions

- Writes go through `PlayerSaveStore.persistBatch` (Bool-returning) or `performBatchMutation` (throwing), and domain extensions on `PlayerSaveStore`
- Mutations diff `PlayerSaveSlice` values and reconcile only changed slices, preserving retained child-row identities; failed writes use snapshot compensation as defined in the [persistence guide](../../Docs/AgentContext/persistence.md)
- Cross-slice domain actions live in domain extensions on `PlayerSaveStore` (e.g. `PlayerSaveStore+Homestead.swift`)
- Victory applies a resolved `BattleRewardAward`; gross Gold gains and spending stay separate until award resolution. Shared reward contracts and prepared-completion policy live in [persistence context](../../Docs/AgentContext/persistence.md).
- Store methods are `@MainActor`; pure reward/sanitize math (`BattleLoot`, `StageCompletion`, `VictoryRewardApplier`, appliers) stays non-isolated `save: inout` so app sessions decide when to apply
- Tests use `SaveTestSupport` with `disableCloudSync: true`; write-through tests follow the [Testing.md](../../Docs/Platform/Testing.md) mutate → reload rubric. The `-disable-cloud-sync` launch argument is for the app / UI tests via `AppEnvironment`, not package unit tests.

Live CloudKit stays off until [CloudKitPreShipChecklist.md](../../Docs/Platform/CloudKitPreShipChecklist.md).

```sh
./Scripts/test-package.sh TrinketPersistence
```

Purchase access is a transient `PlayerSaveStore.contentAccess` input supplied by
AppState from StoreKit. It is never serialized into the player save or synced
through CloudKit. [Purchases](../../Docs/Platform/Purchases.md) owns the lifecycle.
