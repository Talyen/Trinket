# CloudKit Pre-Ship Checklist

Use before enabling CloudKit sync in production or submitting Trinket with iCloud progress sync.

This guide owns the remaining CloudKit enablement work and the repeatable release
checklist. It is not a code-quality audit. Source checks can run locally;
account, portal, and device checks require access to the corresponding Apple services.

Do not check boxes into git as durable state — leave items unchecked in the committed file. Record build-specific outcomes in the release handoff or TestFlight notes.

**Apple Developer Program:** A paid membership is required to create the CloudKit container, fill production entitlements, and verify multi-device sync. Local SwiftData, privacy-manifest prep, and `-disable-cloud-sync` testing do **not** require an account.

**Current ship posture:** Ordinary builds default to **local-only** progress.
Explicitly enabled internal TestFlight builds use CloudKit Production for controlled
testing; wider distribution remains subject to the readiness gates below.
`-enable-cloud-sync` opts a Debug installation in and retains that preference
for later launches; `-disable-cloud-sync` clears it. The pure environment parser
and test/reset overrides remain credential-free.
`CLOUDKIT_SYNC_ENABLED` in `project.yml` defaults to `NO`. A build made with `YES`
requests automatic sync, including Release; Release ignores the Debug opt-in
argument and saved preference. Tests, `-disable-cloud-sync`,
`-reset-state`, and `-seed-test-progress` force local storage. The save-store
initializer also defaults to local storage.
SwiftData stays local in every configuration. An explicit CloudKit service handles
complete-save exchange. `project.yml` generates the iCloud/Push entitlements and
background modes for controlled Development verification; provisioning alone does
not establish readiness. Change the distributed default and player-facing sync
copy only after the gates below pass.

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

- [ ] Verify first-sync and concurrent-play reconciliation against the approved
  [complete-save selection policy](../AgentContext/persistence-storage.md#cloudkit-preparation):
  prefer shared-history continuation, Campaign progress, then recency and a stable
  tie-breaker; preserve the other save as a recovery backup before replacement.
  Players receive no save-conflict choices. Preserve the existing TestFlight save;
  never replace it with a fresh root during enablement.
- [ ] Keep the selected save's currency/materials, reward claims, inventory/equipment,
  recruitment/talents, Campaign, Spires, Labyrinth, Contracts, and Homestead consistent
  together. Independent field merging and balance addition do not implement this
  policy. Implement complete-save exchange, backup durability, and replay-safe
  production authority before enabling cloud play.
- [ ] Implement and verify the approved reset/account policy in the
  [storage contract](../AgentContext/persistence-storage.md#cloudkit-preparation):
  reset wins over older offline saves, sign-out retains a local copy, and account
  changes cannot leak prior-account progress into a new container.

These decisions do not authorize hosted accounts, a manual sync funnel, or an
unapproved merge algorithm.

### 2. Persistence safety

- [ ] Prove upgrade and rollback against a populated beta save. SwiftData always
  opens the existing local URL with mirroring disabled. The optional
  `PlayerSaveRoot.cloudStatePayload` adds local outbox/account metadata; value schema
  18 is unchanged. Store-open errors preserve the original files. Disabling sync
  must retain both current progress and metadata at that same URL.
- [ ] Verify complete-save reconciliation and atomic conflict backups. The explicit
  service implements the approved selection policy and rejects stale reset epochs
  and production sequences. Remote imports refresh observed values, preserve newer
  local mutations, and invalidate stale encounter sessions. Own upload acknowledgements
  must not interrupt gameplay. Native SwiftData root mirroring is removed; duplicate
  local roots still fail safely when opening for cloud play.
- [ ] Verify the asynchronous Homestead commands against the canonical authority.
  Linked cloud collection/upgrades require a server response; ordinary offline
  gameplay and confirmed signed-out local collection remain available.
- [ ] Verify server-time settlement, old-rate settlement on upgrade, change-tag retry,
  and replay-safe wallet application. Head, cursor, wallet, and operation receipt
  commit atomically. A receipt survives response loss or termination; a snapshot
  predating a committed claim/upgrade cannot undo it or reopen its interval. Isolated
  tests cover these rules, but real `serverRecordChanged`, network failures, and
  interrupted application still need Development/device evidence.
- [ ] Retain isolated, credential-free tests and CI. `TestLaunchArg` and `AppEnvironment`
  keep tests/reset local; persistence fixtures use in-memory or unique temporary
  stores. Cover root creation, reset, test seeding, graph mutations, and disk reload.

### 3. Development verification

- [ ] Recheck the setup baseline against the signed build. Edit authored `project.yml`
  and regenerate; `Trinket/Info.plist` and `Trinket/Trinket.entitlements` are generated
  outputs. Match the registered app ID, private container,
  `com.apple.developer.icloud-services = CloudKit`, container identifiers,
  Push Notifications and signed `aps-environment` to the provisioning profile.
  Add Remote notifications background mode for background change delivery. Keep
  development opt-in and distributed builds local-only during these trials.
- [ ] Initialize and inspect the explicit Development schema in private custom zone
  `TrinketProgressV1`: `TrinketSaveHead` (`payload`: Asset, `clockProbe`: String),
  `TrinketSaveBackup` (`payload`: Asset), and `TrinketSaveOperation` (`payload`: Bytes).
  Head and backup assets carry versioned complete snapshots; operations carry immutable
  receipts. The service creates the zone and head subscription during authenticated
  Development use. SwiftData models are local and are not deployed as CloudKit records.
  Do not force Production onto Development builds.
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

## Prepared TestFlight activation

TestFlight always uses CloudKit **Production**, including internal testing.
Deploying a CloudKit schema does not submit the app for App Review or release it.
Preparing and compiling an enabled Release build does not access Production;
installing/running that distributed build does. Keep these actions distinct.

The build switch is ready without another save-code change:

| Build | `CLOUDKIT_SYNC_ENABLED` | CloudKit environment |
|---|---|---|
| Ordinary Debug | `NO`; explicit retained launch opt-in available | Development |
| Ordinary Release / rollback | `NO` | Production entitlement, sync inactive |
| Intended cloud-enabled TestFlight archive | `YES` | Production |

The setting expands into `TrinketCloudSyncEnabled` in the built Info.plist.
Inspect that value together with `TrinketCloudEnvironment` and the final signed
entitlements; passing a Debug launch argument does not enable TestFlight.

After the Development gates pass, the remaining activation sequence is:

1. In CloudKit Console, select `iCloud.com.ryanmcintire.Trinket`, review the
   Development-to-Production schema changes, and deploy the three explicit record
   types above. This promotes structure, not Development player records.
2. Choose the next internal beta build number in `project.yml`, regenerate, and
   archive scheme `Trinket` in Release with `CLOUDKIT_SYNC_ENABLED=YES`. Keep the
   existing bundle ID and verify Production entitlements when exporting for
   App Store Connect. Leave the checked-in default `NO` until adoption is verified.
3. Upload only to internal TestFlight, attach the prepared cloud beta notes from
   [AppStoreMetadata.md](AppStoreMetadata.md#cloud-enabled-beta-copy), and run the
   critical two-device/restart/reset/production-claim checks in Production. This
   requires a Production-capable second device/build; the ordinary Debug Simulator
   uses Development and cannot verify the TestFlight user's Production save.
4. Reconcile privacy/support copy with the enabled beta. Keep the App Store version
   and Full Game purchase out of App Review until the owner requests submission.

If a rollback is needed, distribute a higher build number with
`CLOUDKIT_SYNC_ENABLED=NO`; do not delete the local store or cloud records.
The tested account/production detachment policy remains in the
[storage contract](../AgentContext/persistence-storage.md#cloudkit-preparation).

## Optional post-launch follow-ups

These do not gate CloudKit enablement:

- Quiet Options sync status, only if useful; follow [Identity](../Product/Identity.md).
- CloudKit Dashboard telemetry review for errors and throttling.

## Apple references

- [CloudKit model setup](https://developer.apple.com/documentation/coredata/setting-up-core-data-with-cloudkit)
- [Remote import handling](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit)
- [Schema deployment](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)
- [Development and TestFlight testing](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/TestingYourApp/TestingYourApp.html)
