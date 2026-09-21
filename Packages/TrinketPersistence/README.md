# TrinketPersistence

Player save model and SwiftData stores. Graph and hub details: [persistence.md](../../Docs/AgentContext/persistence.md). DAG: [Architecture.md](../../Docs/Platform/Architecture.md).

## Structure

Under `Sources/TrinketPersistence/`, the root holds the save/store facade,
configuration, sanitization, and roster hydration. Domain operations live in
`Progression/` (battle rewards and mode completion), `Encounters/` (Mystery and
Shop claims and saved offers), and `Inventory/` (stored items, salvage, and
corruption). `Models/` holds value models; `PlayerSaveGraph/` holds SwiftData
models and mapping. All folders remain in the same target.

## Concern guides

[Persistence ownership](../../Docs/AgentContext/persistence.md) owns commands,
transaction outcomes, observation and reload evidence. Detailed contracts live in
[storage](../../Docs/AgentContext/persistence-storage.md) and
[progression](../../Docs/AgentContext/persistence-progression.md).

Store methods are `@MainActor`; pure reward/sanitize math (`BattleLoot`,
`StageCompletion`, `VictoryRewardApplier`, appliers) stays non-isolated
`save: inout` so app sessions decide when to apply. Mutations reconcile changed
slices while preserving retained child-row identities.

## Doctrine

Heal-locally / reject-remotely: store open sanitizes without validating so a
locally readable save always loads; commit, reset, and cloud-restore share
`PlayerSaveSanitizer.sanitizeAndValidate`, and cloud restores additionally
refuse unreadable Labyrinth maps so corrupt snapshots never propagate.
`PlayerSavePersistenceError.mapped` preserves typed causes end to end, and
`isRetryable` gates silent retries (validation rejections never retry).

Item degradation is per-field, shared by the SwiftData, offer-blob, and cloud
codecs via `ItemResolution`: unknown bases drop the item, unknown keywords are
stripped, unknown rarities fall back to basic, stored affixes round-trip
verbatim (bespoke unique signatures live outside the generic affix catalog).
Offer resolvers drop homeless options and keep surviving offers.

Naming: `*Completion` finishes a game mode (Journey stage, Spire floor,
Labyrinth node, Contract); `*Applier` mutates the save; `*Persistence`
owns a payload codec. Completions return `EncounterCompletion`
(`completed` / `alreadyCompleted` / `unavailable`) and are idempotent:
duplicate deliveries grant nothing further. Value→graph is `init(save:)`,
graph→value is `toPlayerSave()`/`toPlayerRosterState()` and friends,
CloudKit-only is `restored()`, content-ID lookups are `resolve()`.

Reward and claim contracts live in [progression](../../Docs/AgentContext/persistence-progression.md).
Known differences between current behavior and intended product rules are recorded
with [Contracts](../../Docs/Product/Contracts.md#implementation-discrepancy) and
[Mystery events](../../Docs/Product/MysteryEvents.md#implementation-discrepancy);
do not treat a package summary as approval to resolve those product choices.

Tests use `SaveTestSupport` with `disableCloudSync: true`. The
`-disable-cloud-sync` launch argument belongs to app / UI tests through
`AppEnvironment`, not package unit tests.

Ordinary builds default to local-only; explicitly enabled builds use complete-save
sync. Enablement and wider distribution follow
[CloudKitPreShipChecklist.md](../../Docs/Platform/CloudKitPreShipChecklist.md).

```sh
./Scripts/test-package.sh TrinketPersistence
```

Purchase access is a transient `PlayerSaveStore.contentAccess` input supplied by
AppState from StoreKit. It is never serialized into the player save or synced
through CloudKit. [Purchases](../../Docs/Platform/Purchases.md) owns the lifecycle.
