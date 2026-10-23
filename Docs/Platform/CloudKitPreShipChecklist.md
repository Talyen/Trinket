# CloudKit Pre-Ship Checklist

Use before enabling Production sync or submitting Trinket with iCloud progress sync.
Keep these repeatable gates unchecked in Git; record candidate build IDs, outcomes,
and missing evidence in release handoffs or TestFlight notes.

**Current posture:** ordinary builds remain local-only. Explicit internal TestFlight
builds may use Production for controlled testing; wider enablement requires all
readiness stages below. Complete-save sync is implemented, but historical sync
success and closure of its implementation plan do not establish current live readiness.
[App Store readiness](AppStoreMetadata.md#read-only-readiness-check-october-12-2026)
records the dated purchase/cloud evidence snapshot.

A paid Apple Developer membership is required for provisioning and multi-device
sync verification. Local SwiftData and cloud-disabled checks need none. Identity
remains [guest-first](../Product/Identity.md), with no in-app account or login funnel.
[Storage](../AgentContext/persistence-storage.md#cloudkit-preparation) owns build flags,
isolation, merge, recovery, reset, and account policy; this checklist verifies them.

## Setup baseline

Recheck these identities against the candidate's signing and provisioning:

| Service | Existing identity |
|---|---|
| Bundle / app ID | `com.ryanmcintire.Trinket`, with iCloud and Push Notifications |
| Private CloudKit container | `iCloud.com.ryanmcintire.Trinket` |
| App Store Connect | `6811284921`, currently **Trinket!** |

Banking/tax and [Full Game purchases](Purchases.md) are separate StoreKit work;
they do not block CloudKit development. Provisioning alone completes no readiness gate.

## Remaining live verification

Resume when test accounts, controllable devices, and a named cloud-enabled build
are available, or before changing the distributed default or submitting with sync.
The validation scenarios below include the outstanding account, failure, upgrade,
starter-navigation, reset, and concurrent/interrupted Homestead evidence.
[Player coverage](PlayerCoverage.md) provides isolated transport and process-exit
proof; live Development and TestFlight checks remain required. Reconcile disclosures
only after the relevant gates pass. Use [Release](Release.md#local-testflight-deployment)
for clean-source and deployment prerequisites.

## Validation scenarios

Use this set for source/isolated proof in stages 1–2, live Development in stage 3,
and the critical device scenarios in stage 4. Record the actual scope at each stage.

| Scenario | Required result |
|---|---|
| First attachment and concurrent progress | Fresh B imports A; populated saves merge under the approved policy without prompts. Preserve the existing beta save, coherent wallet/items/claims/unlocks/world progress, and atomic conflict backups. Remote progress appears while the app stays open. |
| Account boundaries | Switching accounts, sign-out and restricted accounts preserve local play and account separation; sign-out retains a local copy. |
| Network, quota and interrupted requests | Network loss/reconnect, quota errors, `serverRecordChanged`, lost responses and termination preserve accepted actions and once-only replay. |
| Upgrade and rollback | A populated beta save survives restart, upgrade and sync disablement at its existing URL, including outbox/account metadata. Store-open errors preserve original files. |
| Remote publication | Preserve newer local mutations, invalidate stale encounters, and refresh imported starter-choice navigation. Own-upload acknowledgements do not interrupt gameplay. |
| Reset with an offline device | Reset propagates and invalidates outstanding claims; reconnecting stale devices cannot resurrect prior progress. |
| Homestead actions | Offline Collect/Upgrade complete after durable local writes. Overlapping production pays once; distinct upgrades survive. Concurrent Collect/Upgrade preserve the production cursor; interrupted uploads cannot lose or duplicate rewards. |

## Required readiness gates

Complete stages in order. Source and isolated tests are agent-checkable; portal,
signing and device checks require the corresponding services and hardware.
Stages 1–2 precede controlled Development play; stages 3–4 precede wider enablement.

### 1. Product decisions

- [ ] Confirm the candidate follows the approved [reconciliation and reset/account
  contracts](../AgentContext/persistence-storage.md#cloudkit-preparation), including
  action-journal reload, independent earnings, claim deduplication, zero-floored
  concurrent spending, and durable conflict backups. These are existing decisions,
  not authorization for a new merge algorithm, hosted accounts, or manual sync UI.

### 2. Persistence safety

- [ ] Establish the validation scenarios through source and isolated tests before
  live trials. Keep the existing local SwiftData URL and mirroring disabled;
  explicit sync owns complete-save projection and atomic head/backup commits.
  Reject stale reset epochs and production sequences; duplicate local roots fail
  safely when opening for cloud play.
- [ ] Prove populated upgrade/rollback, failure preservation, local offline action
  acceptance, and replay-safe legacy receipts. Retain credential-free coverage
  for root creation, reset, test seeding, mutations and disk reload. Test/reset
  configurations use memory or unique temporary stores through `TestLaunchArg`
  and `AppEnvironment`.

### 3. Development verification

- [ ] Match the baseline identities to the signed candidate. Edit authored
  `project.yml` and regenerate Info.plist/entitlements. Check
  `com.apple.developer.icloud-services = CloudKit` and
  container identifiers, Push Notifications, signed `aps-environment`, and Remote
  notifications background mode. Keep the distributed default local-only.
- [ ] Initialize and inspect private Development zone `TrinketProgressV1`:
  `TrinketSaveHead` (`payload`: Asset, `clockProbe`: String), `TrinketSaveBackup`
  (`payload`: Asset), and `TrinketSaveOperation` (`payload`: Bytes). Heads/backups
  carry complete snapshots; operations carry immutable receipts. Authenticated
  Development use creates the zone and head subscription. SwiftData models stay local.
- [ ] Run the validation scenarios on two devices, or Simulator plus device, in
  the same iCloud account. Verify actual import/export and receiving-app behavior;
  container-open success is insufficient. Keep Development separate from Production.

### 4. TestFlight promotion

- [ ] After Development passes, follow [prepared activation](#prepared-testflight-activation).
  Repeat stage 3's critical device scenarios and stage 2's populated rollback proof
  on an internal Production build over the existing local-save beta.
- [ ] Ship `PrivacyInfo.xcprivacy` and reconcile optional-sync, offline/no-login,
  and propagated-reset disclosures against observed behavior. General support/privacy
  and App Privacy preparation follow [Release](Release.md#prepare-while-the-beta-is-running)
  and [Apple's privacy definitions](https://developer.apple.com/app-store/app-privacy-details/).
  Keep existing local-only disclosures until sync ships; promise no manual sync controls.
- [ ] Change the automatic-sync default only after all gates pass. Retain tested
  rollback, repeat affected checks after implementation/provisioning changes, and
  verify Production again before App Store submission.

## Prepared TestFlight activation

TestFlight uses **Production**, including internal testing. Schema deployment
changes structure, not Development player records, and submits no app for review.
Preparing/compiling a build accesses no Production save; running it can.

| Build | `CLOUDKIT_SYNC_ENABLED` | Environment |
|---|---|---|
| Ordinary Debug | `NO`; explicit retained development opt-in | Development |
| Ordinary Release / rollback | `NO` | Production entitlement, sync inactive |
| Intended internal cloud TestFlight archive | Explicit `YES` override | Production |

The switch expands into `TrinketCloudSyncEnabled` in Info.plist. Verify it with
`TrinketCloudEnvironment` and signed entitlements; Debug arguments do not enable TestFlight.

After Development gates pass:

1. Review and deploy the existing container's Development schema to Production in
   CloudKit Console, using deliberate test saves.
2. Archive scheme `Trinket` in Release at the next internal beta build number with
   `CLOUDKIT_SYNC_ENABLED=YES`. Preserve the bundle ID, check Production export
   entitlements, and leave the checked-in default `NO` until adoption is verified.
3. Upload only to internal TestFlight with the prepared [cloud beta notes](AppStoreMetadata.md#cloud-enabled-beta-copy).
   Complete stage 4 using a Production-capable second device/build; an ordinary
   Debug Simulator cannot verify the TestFlight user's Production save.
4. Reconcile support/privacy copy for that beta. App Store and Full Game review
   submission remain separate owner-requested actions.

Rollback distributes a higher build number with `CLOUDKIT_SYNC_ENABLED=NO`,
preserving local stores and cloud records under the existing
[account/production detachment policy](../AgentContext/persistence-storage.md#reset-and-account-isolation).

## Apple references

- [Schema deployment](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)
- [Development and TestFlight testing](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/TestingYourApp/TestingYourApp.html)
