# CloudKit Pre-Ship Checklist

Use before enabling CloudKit sync in production or submitting Trinket to the App Store.

This is a **release checklist**, not a code-quality audit. Agent-checkable items are marked; device/dashboard steps need a human.

Do not check boxes into git as durable state — leave items unchecked in the committed file. Track completion in the release PR or TestFlight notes.

## Agent-checkable (repo invariants)

Confirm in source / CI config:

- [ ] App ID / entitlements: `Trinket.entitlements` includes CloudKit and container `iCloud.com.ryanmcintire.Trinket`
- [ ] Unit/UI tests default to **`-disable-cloud-sync`** (`TestLaunchArg.testLaunchArgs` / `AppEnvironment`)
- [ ] No CI job depends on iCloud credentials or CloudKit network access
- [ ] Persistence tests use in-memory or isolated temp stores (no leaked SQLite across runs)
- [ ] SwiftData persistence tests cover root creation, reset, test seed, relaunch from the same URL, and graph mutations

## Apple Developer & CloudKit Dashboard (human)

- [ ] Enrolled in the **Apple Developer Program**
- [ ] App ID `com.ryanmcintire.Trinket` has **iCloud** capability enabled
- [ ] CloudKit container **`iCloud.com.ryanmcintire.Trinket`** exists and matches entitlements
- [ ] SwiftData CloudKit schema validates in Development for the full player object graph (`PlayerSaveRoot`, journey, roster, inventory, homestead children)
- [ ] Schema review: CloudKit-compatible SwiftData constraints (optional relationships, defaults/optionals on scalars, no `@Attribute(.unique)`)
- [ ] **Production** schema deployed (promoted from Development) before App Store release

## Device & Account Testing (human)

- [ ] Two devices (or Simulator + device) on the **same iCloud account**
- [ ] Fresh install on B pulls progress from A after sync
- [ ] Independent updates merge (gold, stage, item, homestead tier)
- [ ] **Reset Game Progress** replaces local progress and propagates
- [ ] Playable when **not** signed into iCloud (local-only)
- [ ] Account status changes handled (signed out / restricted → local fallback)
- [ ] Playable **offline**; sync resumes when connectivity returns
- [ ] Concurrent writes to separate properties converge without custom app reconciliation

## App Store & Privacy (human)

- [ ] Privacy questionnaire declares **iCloud sync of game progress**
- [ ] App Review notes: offline playable; iCloud optional for cross-device sync
- [ ] Options/reset copy describes cloud-backed progress without promising manual sync controls

## Release Engineering (human)

- [ ] TestFlight verified against Development CloudKit environment
- [ ] Production CloudKit verified after schema promotion
- [ ] Rollback plan: ship update with CloudKit disabled while preserving local SwiftData storage
