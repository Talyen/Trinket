# CloudKit Pre-Ship Checklist

Use before enabling CloudKit sync in production or submitting Trinket with iCloud progress sync.

This guide owns the remaining CloudKit enablement work and the repeatable release
checklist. It is not a code-quality audit. Source checks can run locally;
account, portal, and device checks require access to the corresponding Apple services.

Do not check boxes into git as durable state — leave items unchecked in the committed file. Record build-specific outcomes in the release handoff or TestFlight notes.

**Apple Developer Program:** A paid membership is required to create the CloudKit container, fill production entitlements, and verify multi-device sync. Local SwiftData, privacy-manifest prep, and `-disable-cloud-sync` testing do **not** require an account.

**Current ship posture:** Progress is **local-only**, including TestFlight.
`AppEnvironment.parse` disables CloudKit unless `-enable-cloud-sync` is passed;
tests, `-disable-cloud-sync`, and `-reset-state` force local storage.
`Trinket/Trinket.entitlements` is still empty. Provisioning alone is not permission
to enable sync. Add app capabilities for controlled development testing only after
the safety requirements below are implemented; change the distributed default and
player-facing sync copy only after verification.

**Identity:** Cross-device progress uses this CloudKit private container — not Sign in with Apple / Google. Guest-first, no login UI. See [Identity.md](../Product/Identity.md).

## Setup baseline

Verified during Apple account setup on September 11, 2026; recheck provisioning
when preparing a cloud-enabled build. These facts do not check off the release gates.

| Area | Established |
|---|---|
| Membership/signing | Paid developer team `Y968D69P94` is active and recognized by Xcode. |
| App ID | `com.ryanmcintire.Trinket` is registered with iCloud and Push Notifications enabled. |
| Container | `iCloud.com.ryanmcintire.Trinket` exists and is assigned to the app ID. |
| Distribution | App Store Connect record **Trinket: Heroes & Companions** (`6811284921`) exists. Internal TestFlight `0.1.0 (1)` was installed and launched successfully, as reported by the owner. |

Banking/tax completion and Full Game purchase testing are separate StoreKit work
and do not block CloudKit development. See [Purchases.md](Purchases.md).

## Required readiness gates

Complete these stages in order. Source and isolated test checks are agent-checkable;
portal, signing, and device checks need the corresponding account and hardware.
Stages 1–2 establish safety before a controlled cloud-enabled Development build;
stages 3–4 prove readiness before changing the distributed default.

### 1. Product decisions

Persistence owns save policy; AppState owns lifecycle coordination. Record approved
outcomes in the [persistence contracts](../AgentContext/persistence.md) before
implementing the unresolved choices:

- [ ] Define first-sync reconciliation when two devices already have different local
  progress. Preserve the existing TestFlight save; neither replacing it with a fresh
  root nor silently picking one device is acceptable.
- [ ] Define conflict outcomes for earned/spent currency and materials, reward claims,
  inventory/equipment, recruitment/talents, Campaign and Spire completion, Labyrinth,
  Contracts, and Homestead upgrades. Framework field merging is not a game-level
  policy for preventing duplicate rewards, double spending, or invalid relationships.
- [ ] Define reset precedence, including an offline device returning with pre-reset
  progress, and account switching/sign-out behavior that prevents progress from
  leaking into another account's container.

These decisions do not authorize hosted accounts, a manual sync funnel, or an
unapproved merge algorithm.

### 2. Persistence safety

- [ ] Preserve or explicitly migrate the store URL and schema when moving from
  `PlayerSaveStoreConfiguration.resolveStore`'s explicit local URL to its private
  CloudKit configuration. Prove upgrade and rollback against a populated local save;
  disabling sync must not select an empty or stale alternate store.
- [ ] Replace any unsafe cloud root reconciliation. `fetchRoot` currently keeps the
  newest root and deletes extras; that local repair is not a cloud conflict strategy.
  Remote imports must refresh observed values without overwriting pending local work
  or requiring an app restart.
- [ ] Enforce Homestead cloud readiness before cloud-enabled play. `collectProduction`
  currently performs a local batch despite the `cloudSyncUnsupported` result case;
  upgrades also settle production locally. Gate both paths until the canonical cloud
  production/claim authority exists. Keep local-only collection working.
- [ ] Implement that authority with interval identity, authoritative time, old-rate
  settlement on upgrade, conflict retry, and replay-safe wallet application. Cover
  idempotent collection, cursor conflicts, `serverRecordChanged`, and interrupted
  application. Offline cloud players can view pending production but claims wait for
  the authority; ordinary offline gameplay remains available.
- [ ] Retain isolated, credential-free tests and CI. `TestLaunchArg` and `AppEnvironment`
  keep tests/reset local; persistence fixtures use in-memory or unique temporary
  stores. Cover root creation, reset, test seeding, graph mutations, and disk reload.

### 3. Development verification

- [ ] Recheck the setup baseline against the signed build. Edit authored `project.yml`
  and entitlements, then regenerate. Match the registered app ID, private container,
  `com.apple.developer.icloud-services = CloudKit`, container identifiers,
  Push Notifications and signed `aps-environment` to the provisioning profile.
  Add Remote notifications background mode for background change delivery. Keep
  development opt-in and distributed builds local-only during these trials.
- [ ] Validate and initialize the complete SwiftData Development schema: root,
  Journey, roster, inventory, Homestead, aspects, Labyrinth, and the chosen production
  authority records. Preserve optional relationships, scalar defaults/optionals,
  and absence of `@Attribute(.unique)`. Do not force Production onto Development builds.
- [ ] Verify actual import/export on two devices (or Simulator plus device) using
  the same iCloud account: fresh B imports A, two populated saves reconcile according
  to stage 1, concurrent domain changes honor that policy, and remote progress appears
  while the receiving app remains open. Container-open success alone is insufficient.
- [ ] Verify reset propagation and invalidation of outstanding production claims,
  including an offline device reconnecting without resurrecting pre-reset progress.
  Exercise switching accounts, sign-out, restricted accounts, unavailable network,
  quota/errors, and reconnect; preserve local play and account separation.
- [ ] Verify two devices collecting the same production interval grant it once;
  concurrent Collect and Upgrade settle the old rate once; termination after a
  successful server claim neither loses nor duplicates rewards on retry. Exercise
  the offline claim behavior established in stage 2.

### 4. TestFlight promotion

- [ ] After Development passes, review and deploy the schema to Production using
  deliberate test saves. Schema promotion does not copy Development player records.
  TestFlight uses Production CloudKit and cannot be the first Development test.
- [ ] Verify a cloud-enabled internal TestFlight update over the existing local-save
  beta, repeating stage 3's critical device scenarios and stage 2's rollback proof.
  Record actual outcomes and build IDs. Preserve source identifiers even though the
  App Store display name includes “Heroes & Companions.”
- [ ] Ship `PrivacyInfo.xcprivacy` and review its declarations, App Store privacy
  answers, support/privacy pages, Options/reset copy, and review notes against actual
  behavior. Describe optional iCloud sync, offline play without login, and propagated
  reset accurately; do not promise manual sync controls. Keep existing local-only
  disclosures until sync ships. Use [Apple's privacy definitions](https://developer.apple.com/app-store/app-privacy-details/).
- [ ] Enable automatic sync by default only after the required gates pass. Retain the
  tested rollback and repeat relevant checks when the implementation or provisioning
  changes. Verify Production again before App Store submission.

## Optional post-launch follow-ups

These do not gate CloudKit enablement:

- Quiet Options sync status, only if useful; follow [Identity](../Product/Identity.md).
- CloudKit Dashboard telemetry review for errors and throttling.

## Apple references

- [CloudKit model setup](https://developer.apple.com/documentation/coredata/setting-up-core-data-with-cloudkit)
- [Remote import handling](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit)
- [Schema deployment](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)
- [Development and TestFlight testing](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/TestingYourApp/TestingYourApp.html)
