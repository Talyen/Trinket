# CloudKit Pre-Ship Checklist

Use when preparing a cloud-enabled build or submitting Trinket with iCloud progress
sync. The scenarios below are a reusable catalog, not a fresh list of failed checks
for every build. Record candidate build IDs, reused evidence, affected changes, and
remaining checks in the release handoff or TestFlight notes. Unchecked boxes describe
repeatable requirements; they do not mean the scenario has never passed.

**Current posture:** ordinary builds remain local-only. Explicit internal TestFlight
builds may use Production for controlled testing; wider enablement requires all
readiness stages below. Complete-save sync is implemented, but historical sync
success and closure of its implementation plan do not establish current live readiness.
[Candidate evidence](AppStoreMetadata.md#candidate-evidence) distinguishes dated
purchase/cloud observations from the next candidate's release qualification.

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
| App Store Connect | `6811284921`, named **Trinket!** in the [October 12 portal baseline](AppStoreMetadata.md#candidate-evidence) |

Banking/tax and [Full Game purchases](Purchases.md) are separate StoreKit work;
they do not block CloudKit development. Provisioning alone completes no readiness gate.

## Evidence and candidate review

The retained September 13 record is in Git at
`297a4b884^:Docs/Plans/CloudKitLaunchPreparation.md`. It records:

- **Development:** two-way iPhone and Simulator sync and the then-current
  offline-device reset behavior. A disposable-zone server harness verified concurrent
  Homestead collection/upgrade and recovery after a committed response was lost.
- **Production internal TestFlight 0.1.0 (2):** the schema had been deployed;
  the owner's Mac and iPhone synced starter selection and gameplay progress in both
  directions. The Mac retained imported progress after relaunch. Build 3 included a
  starter-navigation fix, but that fix was not retested on the iPhone in this record.

These were real successful tests, not a substitute for all candidate-specific
scenarios. The separately retained Development harness JSON was not present at its
recorded path during the October 26 review. The Git record remains available.

For a new candidate, first identify the intended audience and cloud setting. Compare
the candidate against the tested build and evidence, and identify changed behavior,
schema, signing, environment, or device conditions that affect each relevant
scenario. Reuse evidence where its scope still applies; do not rerun a scenario
solely because its checkbox is unchecked or the build number changed. State what was
reused, what changed, and any evidence that is missing; do not infer a pass from an
unchanged checklist or from synthetic tests. Recheck Production schema and signing
when those inputs may have changed rather than treating the earlier deployment as
proof of their present state.

In the candidate handoff, identify the build and audience, then list each reused
result with its environment and source, each change that affects that result, and
the specific checks still needed. State whether the candidate is local-only, a
controlled cloud test, or qualified for wider cloud release. This record makes the
next review incremental without turning the scenario catalog into a status tracker.

Controlled internal cloud testing and wider release have different purposes. For an
internal test, establish the safety and applicable Development evidence needed for
the intended test, preserve test saves, and name the Production scenarios being
tested. Unverified edge cases are follow-up work, not proof that prior sync never
worked. Before wider enablement or submission, resolve the applicable outstanding
readiness scenarios below and document their evidence; do not silently promote a
controlled test result into broad release qualification.

The September 13 live reset result reflected the old policy: offline progress
did not return. Commit `ba81da0dc` changed that policy so offline progress can
merge back after reset; the prior reset observation cannot verify the new behavior.
Account switching, quota, offline contention, reset, and Homestead Production edge
cases were left as follow-up in the TestFlight record; do not describe all of them
as passed on the strength of the two-way sync test.

On October 27, an iPhone 14 Pro ran explicitly cloud-enabled Development builds
for launch and fresh-restore timing. The `codex/cloud-launch-timing` evidence at
`ba81da0dc` records ten completed launch samples, five with sync enabled, and one
fresh-restore sample. The `codex/faster-cloud-restore` evidence at `02f04d881`
records three completed fresh-restore timing samples after the transport change.
Their retained `measurements.jsonl`, `fresh-restore.jsonl`, and `fresh-after.jsonl`
include launch and CloudKit operation markers. These are completed physical-device
Development observations, not evidence of every two-device reconciliation or
Production/TestFlight scenario. Find the records in Git's shared
`trinket-evidence/codex/` store; retain the accompanying build and save backups.

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
| Reset with an offline device | Reset invalidates old production claims; reconnecting offline progress merges conservatively and can restore previously reset progress. Stale reset requests cannot reset the newer epoch. |
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

- [ ] Establish the applicable safety scenarios through source and isolated tests
  before live trials, reusing evidence where it remains applicable. Keep the existing
  local SwiftData URL and mirroring disabled;
  explicit sync owns complete-save projection and atomic head/backup commits.
  Merge offline uploads across reset epochs without replaying old production receipts;
  reject stale reset requests and production sequences. Duplicate local roots fail
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
- [ ] Verify the missing or invalidated Development scenarios on two devices, or
  Simulator plus device, in the same iCloud account. Where applicable, verify actual
  import/export and receiving-app behavior; container-open success is insufficient.
  Reuse applicable recorded results and keep Development separate from Production.

### 4. TestFlight promotion

- [ ] Follow [prepared activation](#prepared-testflight-activation). On an internal
  Production build over the existing local-save beta, verify missing or invalidated
  critical device scenarios and populated rollback. Reuse applicable Production
  evidence and distinguish it from Development and isolated-test results.
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

After reviewing the applicable Development evidence and the intended internal test:

1. Review the existing container's Production schema in CloudKit Console. Deploy
   required Development schema changes if they are not already present, using
   deliberate test saves; do not repeat a deployment solely because the build changed.
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
