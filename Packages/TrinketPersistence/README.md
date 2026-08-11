# TrinketPersistence

Player save model and SwiftData stores. The schema is CloudKit-ready; shipping builds
remain local-only until the pre-ship enablement checklist is complete.

## Architecture

- **`PlayerSaveStore`** — Hub owning a `ModelContainer`/`ModelContext`. Creates the save root idempotently; owns deferred save, rollback, reset/seed, and slice property setters.
- **`PlayerSaveStoreConfiguration`** — Store URL / `ModelConfiguration` / fetch-root helpers (keeps open plumbing out of the hub body).
- **Domain actions** — `PlayerHomesteadStore` owns cross-slice homestead build/upgrade; single-slice reads/writes use hub properties (`save.journey`, `save.roster`, `save.inventory`, `save.homestead`). Prefer `save.homesteadStore.buildOrUpgradeNode` for homestead player actions.
- **Value types** — `PlayerSave`, `PlayerRosterState`, `PlayerHomesteadState`, etc. hold pure rules and calculation snapshots, not the canonical persisted form.
- **Shell navigation** — selected tab is in-session only (`TrinketAppState.ShellSession`); this package does not own shell UI state. Device-local `OptionsStore` is owned by `TrinketAppState`.

## Key conventions

- Player-save disk/CloudKit writes route through `PlayerSaveStore.performBatchMutation` / slice setters
- A mutation diffs `PlayerSaveSlice` values, reconciles only changed slices, and rolls back only touched slices; preserve stable child-row identities during reconciliation
- Put cross-slice player actions on `PlayerHomesteadStore` (or a real action type), not empty pass-through facades or new hub methods
- Write-through tests: mutate → reload from disk → assert
- All store methods should be `@MainActor`
- Pass `-disable-cloud-sync` in tests to avoid CloudKit network access

## CloudKit

The planned private container is `iCloud.com.ryanmcintire.Trinket`. Live sync is
disabled until entitlements, schema promotion, device conflict testing, and the rest
of `Docs/Platform/CloudKitPreShipChecklist.md` are complete.

## Testing

```sh
./Scripts/test-package.sh TrinketPersistence
```

Use `SaveTestSupport.makeTempDirectory` (`TrinketPersistenceTestSupport` target) and inject stores with the temp file store.
