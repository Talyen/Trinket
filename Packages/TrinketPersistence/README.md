# TrinketPersistence

Player save model, SwiftData stores, and CloudKit sync.

## Architecture

- **`PlayerSaveStore`** — Hub owning a `ModelContainer`/`ModelContext`. Creates the save root idempotently; owns deferred save, rollback, reset/seed, and slice property setters.
- **`PlayerSaveStoreConfiguration`** — Store URL / `ModelConfiguration` / fetch-root helpers (keeps open plumbing out of the hub body).
- **Domain actions** — `PlayerHomesteadStore` owns cross-slice homestead build/upgrade; single-slice reads/writes use hub properties (`save.journey`, `save.roster`, `save.inventory`, `save.homestead`). Prefer `save.homesteadStore.buildOrUpgradeNode` for homestead player actions.
- **Value types** — `PlayerSave`, `PlayerRosterState`, `PlayerHomesteadState`, etc. hold pure rules and calculation snapshots, not the canonical persisted form.
- **Options and shell session** — `OptionsStore` uses `UserDefaults` explicitly. `PlayerShellSessionStore` persists tab, map-scroll, and last Play-mode session keys in a local SwiftData store (not `PlayerSave` / CloudKit), and migrates legacy session keys from `UserDefaults`.

## Key conventions

- Player-save disk/CloudKit writes route through `PlayerSaveStore.performBatchMutation` / slice setters; shell-session writes stay in `PlayerShellSessionStore`
- Put cross-slice player actions on `PlayerHomesteadStore` (or a real action type), not empty pass-through facades or new hub methods
- Write-through tests: mutate → reload from disk → assert
- All store methods should be `@MainActor`
- Pass `-disable-cloud-sync` in tests to avoid CloudKit network access

## CloudKit

Configured with container `iCloud.com.ryanmcintire.Trinket`. OS-managed SwiftData + CloudKit sync. See `Docs/Platform/CloudKitPreShipChecklist.md`.

## Testing

```sh
./Scripts/test-package.sh TrinketPersistence
```

Use `SaveTestSupport.makeTempDirectory` and inject stores with the temp file store.
