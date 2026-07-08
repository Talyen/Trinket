# TrinketPersistence

Player save model, SwiftData stores, and CloudKit sync.

## Architecture

- **`PlayerSaveStore`** — Hub owning a `ModelContainer`/`ModelContext`. Creates the save root idempotently; owns deferred save, rollback, reset/seed, and slice property setters.
- **`PlayerSaveStoreConfiguration`** — Store URL / `ModelConfiguration` / fetch-root helpers (keeps open plumbing out of the hub body).
- **Domain stores** — Thin facades (`PlayerRosterStore`, `PlayerInventoryStore`, `PlayerJourneyStore`, `PlayerHomesteadStore`) wrap the hub; no second container. Prefer `save.homesteadStore.buildOrUpgradeNode` for player actions.
- **Value types** — `PlayerSave`, `PlayerRosterState`, `PlayerHomesteadState`, etc. hold pure rules and calculation snapshots, not the canonical persisted form.
- **Options** — `OptionsStore` uses `UserDefaults` explicitly. `AppState` persists tab and map-scroll session keys via `UserDefaults` (not SwiftData).

## Key conventions

- All disk/CloudKit writes route through `PlayerSaveStore.performBatchMutation` / slice setters
- Put new player actions on `Player*Store`, not new methods on the hub
- Write-through tests: mutate → reload from disk → assert
- All store methods should be `@MainActor`
- Pass `-disable-cloud-sync` in tests to avoid CloudKit network access

## CloudKit

Configured with container `iCloud.com.ryanmcintire.Trinket`. OS-managed SwiftData + CloudKit sync. See `Docs/Audits/CloudKitPreShipChecklist.md`.

## Testing

```sh
./Scripts/test-package.sh TrinketPersistence
```

Use `SaveTestSupport.makeTempDirectory` and inject stores with the temp file store.
