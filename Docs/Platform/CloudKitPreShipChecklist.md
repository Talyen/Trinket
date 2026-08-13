# CloudKit Pre-Ship Checklist

Use before enabling CloudKit sync in production or submitting Trinket with iCloud progress sync.

This is a **release checklist**, not a code-quality audit. Agent-checkable items are marked; device/dashboard steps need a human.

Do not check boxes into git as durable state — leave items unchecked in the committed file. Track completion in TestFlight notes or the release changelog.

**Apple Developer Program:** A paid membership is required to create the CloudKit container, fill production entitlements, and verify multi-device sync. Local SwiftData, privacy-manifest prep, and `-disable-cloud-sync` testing do **not** require an account.

**Current ship posture:** Progress is **local-only**. Simulator and tests keep CloudKit off unless `-enable-cloud-sync` is passed. `Trinket/Trinket.entitlements` stays empty until portal provisioning. Options reset copy refers to this device only. Re-enable iCloud user copy and `UIBackgroundModes: remote-notification` only when live CloudKit lands.

**Identity:** Cross-device progress uses this CloudKit private container — not Sign in with Apple / Google. Guest-first, no login UI. See [Identity.md](../Product/Identity.md).

---

## Prep without Developer Program — agent-checkable

Confirm in source / CI config:

- [ ] Runtime default keeps CloudKit off unless explicitly enabled (`-enable-cloud-sync` on Simulator; `-disable-cloud-sync` / tests / reset always local) — `AppEnvironment.parse`
- [ ] SwiftData models remain CloudKit-compatible (optional relationships, defaults, no `@Attribute(.unique)`)
- [ ] Unit/UI tests default to **`-disable-cloud-sync`** (`TestLaunchArg.testLaunchArgs` / `AppEnvironment`)
- [ ] No CI job depends on iCloud credentials or CloudKit network access
- [ ] Persistence tests use in-memory or isolated temp stores (no leaked SQLite across runs)
- [ ] SwiftData persistence tests cover root creation, reset, test seed, relaunch from the same URL, and graph mutations
- [ ] User-facing reset copy does **not** claim live iCloud sync (`OptionsView` — this device only)
- [ ] `PrivacyInfo.xcprivacy` present (`Trinket/PrivacyInfo.xcprivacy`; no tracking; collected-data empty until sync ships)
- [ ] `INFOPLIST_KEY_UIBackgroundModes: remote-notification` remains absent while sync is disabled (`project.yml`)
- [ ] `PlayerSaveStore.resolveConfiguration` documents local-only vs private CloudKit paths; private path unused until entitlements + portal
- [ ] Entitlements file exists but empty on purpose — do not invent CloudKit keys before Developer Program enrollment
- [ ] Passive Homestead collection has an explicit CloudKit readiness gate; the local collector cannot run while private CloudKit is enabled
- [ ] The CloudKit passive-production authority is implemented before that gate is removed; no UI path writes a local collection while cloud sync is active
- [ ] Passive production tests cover idempotent collection, timestamp/cursor conflict behavior, retry after `serverRecordChanged`, and interrupted local application

---

## Apple Developer & CloudKit Dashboard (human, requires paid membership)

- [ ] Enrolled in the **Apple Developer Program**
- [ ] App ID `com.ryanmcintire.Trinket` has **iCloud** capability enabled
- [ ] CloudKit container **`iCloud.com.ryanmcintire.Trinket`** exists and matches `Trinket/Trinket.entitlements`
- [ ] Entitlements include `com.apple.developer.icloud-services = CloudKit` and `com.apple.developer.icloud-container-identifiers = iCloud.com.ryanmcintire.Trinket`
- [ ] SwiftData CloudKit schema validates in Development for the full player object graph (`PlayerSaveRoot`, journey, roster, inventory, homestead, aspects, labyrinth children)
- [ ] Passive Homestead production state or claim records are present in the Development schema and have a documented canonical owner
- [ ] Schema review: CloudKit-compatible SwiftData constraints (optional relationships, defaults/optionals on scalars, no `@Attribute(.unique)`)
- [ ] **Production** schema deployed (promoted from Development) before App Store release
- [ ] Add Background Modes → Remote notifications
  (`INFOPLIST_KEY_UIBackgroundModes: remote-notification`) before enabling automatic
  SwiftData/CloudKit sync; Apple requires it for background change delivery
- [ ] Device builds can open `cloudKitDatabase: .private(...)` without signing errors

---

## Device & Account Testing (human)

- [ ] Two devices (or Simulator + device) on the **same iCloud account**
- [ ] Fresh install on B pulls progress from A after sync
- [ ] Independent updates merge (gold, stage, item, homestead tier)
- [ ] **Reset Game Progress** replaces local progress and propagates
- [ ] Playable when **not** signed into iCloud (local-only)
- [ ] Account status changes handled (signed out / restricted → local fallback)
- [ ] Playable **offline**; sync resumes when connectivity returns
- [ ] The documented conflict policy is verified for concurrent updates to currency,
  progression, inventory, and relationships; do not assume framework defaults preserve
  game-level invariants
- [ ] Two devices collecting the same Homestead interval result in one claim, not duplicate production
- [ ] Concurrent Collect and Homestead upgrade settles the old rate exactly once before applying the new tier
- [ ] Offline devices can view pending production but cannot claim it until the cloud authority is reachable
- [ ] A successful cloud claim followed by app termination is replay-safe and cannot duplicate wallet materials
- [ ] Reset removes or invalidates outstanding passive-production claims on every device

---

## App Store & Privacy

- [ ] Privacy manifest ships with the app (`PrivacyInfo.xcprivacy`) — tracking off while sync is disabled
- [ ] When enabling sync: privacy questionnaire declares **iCloud sync of game progress**
- [ ] When enabling sync: App Review notes mention offline playable; iCloud optional for cross-device sync
- [ ] When enabling sync: Options/reset copy accurately describes cloud-backed progress without promising manual sync controls
- [ ] When enabling sync: App Review notes align with [Identity.md](../Product/Identity.md) (no login; iCloud optional sync; reset clears progress)

---

## Release Engineering (human)

- [ ] TestFlight verified against Development CloudKit environment
- [ ] Production CloudKit verified after schema promotion
- [ ] Rollback plan: ship update with CloudKit disabled while preserving local SwiftData storage

---

## Optional Follow-Ups (Post-Launch)

- [ ] Game Center achievements / leaderboards (separate from CloudKit save sync; see [Identity.md](../Product/Identity.md) — deferred)
- [ ] Quiet Options iCloud sync status (On/Off) — no prompts; see [Identity.md](../Product/Identity.md)
- [ ] CloudKit Dashboard telemetry review (error rates, throttling)
