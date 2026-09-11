# TrinketPersistence

Player save model and SwiftData stores. Graph and hub details: [persistence.md](../../Docs/AgentContext/persistence.md). DAG: [Architecture.md](../../Docs/Platform/Architecture.md).

## Concern guides

[Persistence ownership](../../Docs/AgentContext/persistence.md) owns commands,
transaction outcomes, observation and reload evidence. Detailed contracts live in
[storage](../../Docs/AgentContext/persistence-storage.md) and
[progression](../../Docs/AgentContext/persistence-progression.md).

Store methods are `@MainActor`; pure reward/sanitize math (`BattleLoot`,
`StageCompletion`, `VictoryRewardApplier`, appliers) stays non-isolated
`save: inout` so app sessions decide when to apply. Mutations reconcile changed
slices while preserving retained child-row identities.

Tests use `SaveTestSupport` with `disableCloudSync: true`. The
`-disable-cloud-sync` launch argument belongs to app / UI tests through
`AppEnvironment`, not package unit tests.

Live CloudKit stays off until [CloudKitPreShipChecklist.md](../../Docs/Platform/CloudKitPreShipChecklist.md).

```sh
./Scripts/test-package.sh TrinketPersistence
```

Purchase access is a transient `PlayerSaveStore.contentAccess` input supplied by
AppState from StoreKit. It is never serialized into the player save or synced
through CloudKit. [Purchases](../../Docs/Platform/Purchases.md) owns the lifecycle.
