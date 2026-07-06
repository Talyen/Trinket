# TrinketPersistence

Player save model, SwiftData stores, and CloudKit sync.

## Architecture

- **`PlayerSaveStore`** — Singleton hub owning a `ModelContainer`/`ModelContext`. Creates the save root idempotently.
- **Domain stores** — `PlayerRosterStore`, `PlayerInventoryStore`, `PlayerJourneyStore`, `PlayerHomesteadStore` — observe/mutate slices through `PlayerSaveStore`.
- **Value types** — `PlayerSave`, `PlayerRosterState`, `StageCompletionContext` are calculation snapshots, not canonical persisted form.
- **Options** — `OptionsStore` and `SessionStateStore` use `UserDefaults` explicitly (not SwiftData).

## Key conventions

- Mutate model objects directly through `PlayerSaveStore`
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
