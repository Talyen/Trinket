# CloudKit Pre-Ship Checklist

Use before enabling CloudKit sync in production or submitting Trinket with iCloud progress sync.

This is a **release checklist**, not a code-quality audit. Agent-checkable items are marked; device/dashboard steps need a human.

Do not check boxes into git as durable state — leave items unchecked in the committed file. Track completion in the release PR or TestFlight notes.

**Apple Developer Program:** A paid membership is required to create the CloudKit container, fill production entitlements, and verify multi-device sync. Local SwiftData, privacy-manifest prep, and `-disable-cloud-sync` testing do **not** require an account — see [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md) Phases F1 vs F2.

**Current ship posture (F1 done, F2 blocked):** Progress is **local-only**. Simulator and tests keep CloudKit off unless `-enable-cloud-sync` is passed. `Trinket.entitlements` stays empty until portal provisioning. Options reset copy refers to this device only. Re-enable iCloud user copy and `UIBackgroundModes: remote-notification` only when F2 lands.

---

## Prep without Developer Program (F1) — agent-checkable

Confirm in source / CI config (expected true after best-practices F1):

- [ ] Runtime default keeps CloudKit off unless explicitly enabled (`-enable-cloud-sync` on Simulator; `-disable-cloud-sync` / tests / reset always local) — `AppEnvironment.parse`
- [ ] SwiftData models remain CloudKit-compatible (optional relationships, defaults, no `@Attribute(.unique)`)
- [ ] Unit/UI tests default to **`-disable-cloud-sync`** (`TestLaunchArg.testLaunchArgs` / `AppEnvironment`)
- [ ] No CI job depends on iCloud credentials or CloudKit network access
- [ ] Persistence tests use in-memory or isolated temp stores (no leaked SQLite across runs)
- [ ] SwiftData persistence tests cover root creation, reset, test seed, relaunch from the same URL, and graph mutations
- [ ] User-facing reset copy does **not** claim live iCloud sync (`OptionsView` — this device only)
- [ ] `PrivacyInfo.xcprivacy` present (`Trinket/PrivacyInfo.xcprivacy`; no tracking; collected-data empty until F2)
- [ ] `INFOPLIST_KEY_UIBackgroundModes: remote-notification` absent until CloudKit sync wakeups are real (`project.yml`)
- [ ] `PlayerSaveStore.resolveConfiguration` documents local-only vs private CloudKit paths; private path unused until entitlements + portal
- [ ] Entitlements file exists but empty on purpose — do not invent CloudKit keys before Developer Program enrollment

---

## Apple Developer & CloudKit Dashboard (F2 — human, requires paid membership)

- [ ] Enrolled in the **Apple Developer Program**
- [ ] App ID `com.ryanmcintire.Trinket` has **iCloud** capability enabled
- [ ] CloudKit container **`iCloud.com.ryanmcintire.Trinket`** exists and matches `Trinket.entitlements`
- [ ] Entitlements include `com.apple.developer.icloud-services = CloudKit` and `com.apple.developer.icloud-container-identifiers = iCloud.com.ryanmcintire.Trinket`
- [ ] SwiftData CloudKit schema validates in Development for the full player object graph (`PlayerSaveRoot`, journey, roster, inventory, homestead, collection attention children)
- [ ] Schema review: CloudKit-compatible SwiftData constraints (optional relationships, defaults/optionals on scalars, no `@Attribute(.unique)`)
- [ ] **Production** schema deployed (promoted from Development) before App Store release
- [ ] Re-add `UIBackgroundModes: remote-notification` in `project.yml` **only if** sync wakeups require it
- [ ] Device builds can open `cloudKitDatabase: .private(...)` without signing errors

---

## Device & Account Testing (F2 — human)

- [ ] Two devices (or Simulator + device) on the **same iCloud account**
- [ ] Fresh install on B pulls progress from A after sync
- [ ] Independent updates merge (gold, stage, item, homestead tier)
- [ ] **Reset Game Progress** replaces local progress and propagates
- [ ] Playable when **not** signed into iCloud (local-only)
- [ ] Account status changes handled (signed out / restricted → local fallback)
- [ ] Playable **offline**; sync resumes when connectivity returns
- [ ] Concurrent writes to separate properties converge without custom app reconciliation

---

## App Store & Privacy

- [ ] Privacy manifest ships with the app (`PrivacyInfo.xcprivacy`) — tracking off while sync is disabled
- [ ] At F2: privacy questionnaire declares **iCloud sync of game progress**
- [ ] At F2: App Review notes mention offline playable; iCloud optional for cross-device sync
- [ ] At F2: Options/reset copy accurately describes cloud-backed progress without promising manual sync controls

---

## Release Engineering (F2 — human)

- [ ] TestFlight verified against Development CloudKit environment
- [ ] Production CloudKit verified after schema promotion
- [ ] Rollback plan: ship update with CloudKit disabled while preserving local SwiftData storage

---

## Optional Follow-Ups (Post-Launch)

- [ ] Game Center achievements / leaderboards (separate from CloudKit save sync)
- [ ] CloudKit Dashboard telemetry review (error rates, throttling)
