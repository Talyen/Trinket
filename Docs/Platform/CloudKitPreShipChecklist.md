# CloudKit Pre-Ship Checklist

Use before enabling CloudKit sync in production or submitting Trinket with iCloud progress sync.

This guide owns the remaining CloudKit enablement work and the repeatable release
checklist. It is not a code-quality audit. Source checks can run locally;
account, portal, and device checks require access to the corresponding Apple services.

Do not check boxes into git as durable state — leave items unchecked in the committed file. Record build-specific outcomes in the release handoff or TestFlight notes.

**Apple Developer Program:** A paid membership is required to create the CloudKit container, fill production entitlements, and verify multi-device sync. Local SwiftData, privacy-manifest prep, and `-disable-cloud-sync` testing do **not** require an account.

**Current ship posture:** Ordinary builds default to **local-only** progress.
Explicitly enabled internal TestFlight builds use CloudKit Production for
controlled testing; wider distribution remains subject to the readiness gates
below. Build-flag, launch-argument, and storage-isolation mechanics live in the
[storage contract](../AgentContext/persistence-storage.md#cloudkit-preparation).
Change the distributed default and player-facing sync copy only after the gates
below pass.

**Identity:** Cross-device progress uses this CloudKit private container — not Sign in with Apple / Google. Guest-first, no login UI. See [Identity.md](../Product/Identity.md).

## Setup baseline

Recheck provisioning in App Store Connect and Xcode when preparing a
cloud-enabled build; these identifiers do not check off the release gates.
Container `iCloud.com.ryanmcintire.Trinket` serves app ID
`com.ryanmcintire.Trinket` (iCloud and Push Notifications enabled); the App
Store Connect record is **Trinket: Heroes & Companions**.

Banking/tax completion and Full Game purchase testing are separate StoreKit work
and do not block CloudKit development. See [Purchases.md](Purchases.md).

## Remaining live verification

The CloudKit implementation plan is closed with verification gaps; closure does
not waive the readiness gates below or enable wider distribution. Complete-save
sync and internal Production testing are implemented. Historical bidirectional
sync evidence does not establish all account and failure scenarios on the current
build. Build-specific outcomes remain in the archived plan's Git history and
release handoffs.

Before wider enablement, obtain the missing live evidence for account switching,
sign-out/restricted accounts, network loss/reconnect, quota failures, populated-save
upgrade/rollback, imported starter-choice navigation, Production reset with an
offline device, and concurrent/interrupted Homestead claims and upgrades. Isolated
transport tests cover relevant invariants but do not replace these device checks.
Reconcile player-facing disclosures after the gates pass.

Resume this validation when suitable test accounts, controllable devices, and a
named cloud-enabled build are available, or before changing the distributed
default or submitting with sync. A new TestFlight build follows the clean-checkout
and deployment prerequisites in [Release](Release.md#local-testflight-deployment).
Until the evidence is obtained, ordinary builds retain their local-only default.

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
  [complete-save selection policy](../AgentContext/persistence-storage.md#cloudkit-preparation)
  (no player conflict prompts; losing save archived as a recovery backup before
  replacement). Preserve the existing TestFlight save;
  never replace it with a fresh root during enablement.
- [ ] Keep the selected save coherent across its wallet, claims, inventory,
  recruitment, and world progress per the [storage contract](../AgentContext/persistence-storage.md#cloudkit-preparation):
  complete-save exchange only, no independent field merging or balance addition.
  Implement complete-save exchange, backup durability, and replay-safe
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
  `PlayerSaveRoot.cloudStatePayload` adds local outbox/account metadata; the
  current value schema (`PlayerSave.currentSchemaVersion`) is unchanged. Store-open errors preserve the original files. Disabling sync
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
- [ ] Ship `PrivacyInfo.xcprivacy` and reconcile the iCloud sync delta against actual
  behavior: optional sync, offline play without login, and propagated reset.
  Do not promise manual sync controls. General support/privacy pages and App Privacy
  answers follow the [release procedure](Release.md#prepare-while-the-beta-is-running);
  keep existing local-only disclosures until sync ships. Use [Apple's privacy definitions](https://developer.apple.com/app-store/app-privacy-details/).
- [ ] Enable automatic sync by default only after the required gates pass. Retain the
  tested rollback and repeat relevant checks when the implementation or provisioning
  changes. Verify Production again before App Store submission.

## Prepared TestFlight activation

TestFlight always uses CloudKit **Production**, including internal testing.
Deploying a CloudKit schema does not submit the app for App Review or release it.
Preparing and compiling an enabled Release build does not access Production;
installing/running that distributed build does. Keep these actions distinct.

The build switch is ready without another save-code change. The checked-in
default stays `NO`; pass `YES` only as an archive-time override for the
intended TestFlight build:

| Build | `CLOUDKIT_SYNC_ENABLED` | CloudKit environment |
|---|---|---|
| Ordinary Debug | `NO`; explicit retained launch opt-in available | Development |
| Ordinary Release / rollback | `NO` | Production entitlement, sync inactive |
| Intended cloud-enabled TestFlight archive | `YES` | Production |

The setting expands into `TrinketCloudSyncEnabled` in the built Info.plist.
Inspect that value together with `TrinketCloudEnvironment` and the final signed
entitlements; passing a Debug launch argument does not enable TestFlight.

After the Development gates pass, the remaining activation sequence is:

1. In CloudKit Console, deploy the Development schema for
   `iCloud.com.ryanmcintire.Trinket` to Production (structure only, not
   Development player records).
2. Archive scheme `Trinket` in Release with `CLOUDKIT_SYNC_ENABLED=YES` at the
   next internal beta build number. Keep the existing bundle ID, verify
   Production entitlements on export, and leave the checked-in default `NO`
   until adoption is verified.
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

## Apple references

- [Schema deployment](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)
- [Development and TestFlight testing](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/TestingYourApp/TestingYourApp.html)
