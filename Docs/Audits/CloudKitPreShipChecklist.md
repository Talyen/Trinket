# CloudKit Pre-Ship Checklist

Use this checklist before enabling CloudKit sync in production or submitting Trinket to the App Store.

## Apple Developer & CloudKit Dashboard

- [ ] Enrolled in the **Apple Developer Program**
- [ ] App ID `com.ryanmcintire.Trinket` has **iCloud** capability enabled
- [ ] CloudKit container **`iCloud.com.ryanmcintire.Trinket`** exists and matches `Trinket.entitlements`
- [ ] Entitlements include `com.apple.developer.icloud-services = CloudKit` and `com.apple.developer.icloud-container-identifiers = iCloud.com.ryanmcintire.Trinket`
- [ ] SwiftData CloudKit schema validates in Development for the full player object graph:
  - `PlayerSaveRoot`
  - `JourneyProgressModel` / `JourneyStageProgressModel`
  - `RosterModel` and combatant progression, ability loadout, equipment, stats children
  - `InventoryModel`, inventory item, and affix children
  - `HomesteadModel`, resource balance, and node tier children
- [ ] Schema review confirms CloudKit-compatible SwiftData constraints: relationship properties optional, scalar properties have defaults or are optional, and no `@Attribute(.unique)` constraints
- [ ] **Production** schema deployed (promoted from Development) before App Store release

## Device & Account Testing

- [ ] Two devices (or Simulator + device) signed into the **same iCloud account**
- [ ] Fresh install on device B pulls progress from device A after sync
- [ ] Progress earned on device A appears on device B after OS-managed SwiftData/CloudKit sync
- [ ] Independent updates merge as expected: gold earned, stage completed, item added, and homestead tier upgraded on different devices
- [ ] **Reset Game Progress** replaces local progress and propagates through CloudKit sync
- [ ] App remains fully playable when **not signed into iCloud** (local-only)
- [ ] Verify app handles iCloud account status changes gracefully (e.g. going from logged in to logged out, or restricted accounts) using container status checks or local fallback logic
- [ ] App remains playable **offline**; sync resumes when connectivity returns
- [ ] Conflict test: concurrent writes to separate records/properties converge without custom app reconciliation

## App Store & Privacy

- [ ] Privacy manifest / App Store questionnaire declares **iCloud sync of game progress**
- [ ] App Review notes mention: offline playable, iCloud optional for cross-device sync
- [ ] Options/reset copy accurately describes cloud-backed game progress without promising manual sync controls

## CI & Automated Tests

- [x] Unit/UI tests run with **`-disable-cloud-sync`** (see `TestLaunchArg.testLaunchArgs` in [AppTypes.swift](../../Trinket/App/AppTypes.swift) and parsed in [AppEnvironment.swift](../../Trinket/App/AppEnvironment.swift))
- [ ] No CI job depends on iCloud credentials or CloudKit network access
- [ ] Verify all unit/integration tests for persistence configure in-memory databases (e.g., `ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)`) in [PlayerSaveStore.swift](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift) to avoid generating SQLite file artifacts or leaking persistent state across test runs
- [ ] SwiftData persistence tests cover root creation, reset, test seed, relaunch from the same SQLite URL, and graph record mutations

## Release Engineering

- [ ] TestFlight build verified with the Development CloudKit environment
- [ ] Production CloudKit environment verified after schema promotion
- [ ] Rollback plan documented if sync causes issues (ship update with CloudKit disabled while preserving local SwiftData storage)

## Optional Follow-Ups (Post-Launch)

- [ ] Game Center achievements / leaderboards (separate from CloudKit save sync)
- [ ] CloudKit Dashboard telemetry review (error rates, throttling)
