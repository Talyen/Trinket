# CloudKit Pre-Ship Checklist

Use this checklist before enabling CloudKit sync in production or submitting Trinket to the App Store.

## Apple Developer & CloudKit Dashboard

- [ ] Enrolled in the **Apple Developer Program**
- [ ] App ID `com.ryanmcintire.Trinket` has **iCloud** capability enabled
- [ ] CloudKit container **`iCloud.com.ryanmcintire.Trinket`** exists and matches `Trinket.entitlements`
- [ ] CloudKit Dashboard **Development** schema includes record type **`PlayerSave`** with fields:
  - `saveData` (Asset)
  - `modifiedAt` (Date/Time, queryable)
  - `schemaVersion` (Int(64))
- [ ] **Production** schema deployed (promoted from Development) before App Store release

## Device & Account Testing

- [ ] Two devices (or Simulator + device) signed into the **same iCloud account**
- [ ] Fresh install on device B pulls progress from device A after sync
- [ ] Progress earned on device A appears on device B after launch or “Sync Now”
- [ ] **Reset Game Progress** overwrites local and iCloud save
- [ ] App remains fully playable when **not signed into iCloud** (local-only)
- [ ] App remains playable **offline**; sync resumes when connectivity returns
- [ ] Conflict test: newer `modifiedAt` wins when both devices have different saves

## App Store & Privacy

- [ ] Privacy manifest / App Store questionnaire declares **iCloud sync of game progress**
- [ ] App Review notes mention: offline playable, iCloud optional for cross-device sync
- [ ] Options screen accurately reflects sync status (available, syncing, unavailable, error)

## CI & Automated Tests

- [ ] Unit/UI tests run with **`-disable-cloud-sync`** (see `TestLaunchArg.testLaunchArgs`)
- [ ] No CI job depends on iCloud credentials or CloudKit network access
- [ ] `PlayerSaveReconcilerTests` and migration tests pass on every build

## Release Engineering

- [ ] TestFlight build verified with Development CloudKit environment
- [ ] Production CloudKit environment verified after schema promotion
- [ ] Rollback plan documented if sync causes issues (ship update with `-disable-cloud-sync` default or hotfix reconciler)

## Optional Follow-Ups (Post-Launch)

- [ ] Game Center achievements / leaderboards (separate from CloudKit save sync)
- [ ] User-visible alert when cloud progress replaces older local progress
- [ ] CloudKit Dashboard telemetry review (error rates, throttling)
