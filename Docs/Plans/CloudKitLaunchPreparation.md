---
type: execution-plan
status: active
created: 2026-09-13
updated: 2026-09-13
expires: 2026-09-27
---

# CloudKitLaunchPreparation

## Objective

Prepare automatic iCloud progress sync and preserve offline play. The owner declared
the existing development progress disposable; the old schema-17 test save was backed
up and explicitly reset. Product conflict and reset/account choices are approved in
the [storage contract](../AgentContext/persistence-storage.md#cloudkit-preparation).
The owner approved the implementation and release-preparation recommendations.
The owner subsequently authorized CloudKit Production deployment and an internal
TestFlight update, with the owner as the only tester and disposable test progress.
App Review submission and public release remain excluded. Banking and tax
certification remain owner actions.

## Plan

- [x] Preserve the configured store URL, default to local storage, and ignore
  development opt-in arguments in Release builds.
- [x] Reject duplicate cloud roots without deleting saves; block both Homestead
  collection and upgrades until the cloud authority exists.
- [x] Add credential-free regression coverage for both guards and preserved local
  play. Record the approved automatic selection and reset/account policies.
- [x] Adopt the missing app-only UserDefaults privacy-manifest declaration; document
  App Store preparation in the [release guide](../Platform/Release.md#prepare-while-the-beta-is-running).
- [x] Approve the complete-save CloudKit architecture below.
- [x] Implement snapshot coding, ancestry, deterministic selection, durable conflict
  backups, account separation, and reset epochs with isolated tests.
- [x] Implement the CloudKit adapter, atomic Homestead authority and replay recovery;
  remove the replaced SwiftData graph mirroring path.
- [x] Wire foreground/import/account lifecycle handling through AppState and existing
  Homestead controls; preserve pending local mutations during asynchronous work.
- [x] Add authored entitlements/background delivery and initialize the chosen
  Development schema after source safety checks pass.
- [x] Verify bidirectional foreground sync and offline-device reset propagation on
  the owner's iPhone and a managed iOS Simulator using the same iCloud account.
- [x] Prepare an explicit `CLOUDKIT_SYNC_ENABLED=YES` build setting for the intended
  TestFlight archive; retain the checked-in `NO` default and local test overrides.
- [ ] Complete the remaining Development failure/account/production-claim scenarios,
  then promote the schema and repeat on an internal TestFlight update.
- [ ] Complete the [CloudKit release checklist](../Platform/CloudKitPreShipChecklist.md),
  archive this plan, and run final handoff over all changed paths.

## Implementation boundary

Keep the existing SwiftData player graph as the local store at its existing URL.
Replace its automatic CloudKit field mirroring with an explicit CloudKit service
inside `TrinketPersistence`; `TrinketAppState` continues to own lifecycle wiring.
Use Apple's CloudKit framework and the existing private container, with no new
account provider or third-party dependency.

The cloud layer exchanges versioned complete-save snapshots with stable revision,
ancestry, account, and reset-epoch identities. Persist local outbox metadata with
the corresponding save. Retain conflicting progress durably before adopting the
winner; a failed backup or upload leaves local progress intact and retryable.
Do not treat container creation, a newer timestamp, or a field merge as proof of
a reconciled save. Legacy first attachment must capture the populated beta save
before downloading or replacing anything.

Use a private custom record zone for an account head, conflict backups, and
production claim receipts. Coordinate head changes, production cursor/rate changes,
and receipt creation atomically with CloudKit change tags. Retry
`serverRecordChanged` using newly fetched state and the same operation identity.
Keep authoritative production time/cursors separate from a branch's device clock;
selecting an older branch cannot reopen a claimed interval. Settle the old rate
before upgrades or branch changes alter Homestead tiers. A server-committed claim
must be recoverable after process termination without applying its wallet reward
twice. Ordinary offline gameplay stays available; cloud claims wait for the server.

Account-specific local state must survive switching accounts without uploading
one account's progress into another. Reset epochs reject pre-reset offline saves
and production receipts regardless of Campaign rank. A late asynchronous import
must not overwrite changes made after its local snapshot was captured, and adopting
remote state must invalidate stale in-progress encounter sessions.

This is a replacement of the sync implementation, not enabling the current private
SwiftData configuration. It changes the cloud schema and persistence orchestration
substantially. The owner approved this replacement and the release recommendations
after reviewing the proposal, under the root
[change guidance](../../AGENTS.md#choose-the-change).

## Notes

The source implementation has isolated coverage for reconciliation, reset/account
separation, atomic production claims, and interrupted application. Bidirectional
Development sync and offline-device reset propagation have passed live checks.
Remaining Development scenarios and Production/TestFlight evidence are still required
before distributed enablement.

GitHub Pages was enabled and workflow run 34735114924 succeeded. Both support and
privacy URLs return HTTP 200. App Store Connect version metadata, manual release,
review contact/no-login, subtitle/categories, and the privacy URL were saved. The
current local-only App Privacy answer is saved but unpublished; no review submission
or release action was taken. Content-rights confirmation is still pending.
The Full Game draft (6811501717) has English localization, the planned US $4.99
price, and Family Sharing enabled after explicit owner confirmation. Neither app
nor purchase has been added for review.

An iPhone save backup was copied before device changes and passed SQLite quick_check:
`/Users/ryanmcintire/Documents/TrinketReleaseBackups/2026-09-13-before-cloud`.
Do not commit that personal save backup or the private review phone number.

Source handoff passed with 141 AppState tests, 266 persistence tests, two shell
smoke tests, script regressions, generation, style, and app compilation. A subsequent
rollback-production regression increased persistence coverage to 267 passing tests.
The final device build signs with team Y968D69P94, the expected CloudKit container,
Development CloudKit environment, development APNs, and background remote delivery.
It was installed and launched successfully on the paired iPhone.

The owner signed managed Simulator agent 1 into the same iCloud account.
Its pre-existing test save was retained outside the repository in
`/Users/ryanmcintire/Documents/TrinketReleaseBackups/simulator-agent-1-before-cloud-20260913`.

Live verification revealed that the owner's installed beta used value schema 17.
The current code rejected it and used temporary fallback storage; unchanged files
alone were not proof of a successful load. The owner explicitly declared the test
progress disposable and requested focus on working CloudKit, so the phone test save
was reset using the explicit named-store reset flow. No schema-17 migration is adopted.

The Simulator's default build omitted entitlements (ENTITLEMENTS_ALLOWED=NO), causing
CKContainer initialization to trap. A scoped Simulator build setting in project.yml
now retains entitlements. The signed Simulator successfully created/read a Development
head with no pending outbox.

Live Development verification succeeded on the paired iPhone and Simulator:
Gold 17 uploaded from iPhone appeared on the still-running Simulator; its change
to Gold 40 appeared on the still-running iPhone. Both had the same account/head
and empty outboxes. The owner reset the Simulator; its server reset count became 1.
The iPhone held an unsynced Gold 45 change with cloud sync disabled under reset
count 0, then reconnected with Gold 0,
starter selection, reset count 1, and an empty outbox. Pre-reset progress did not return.

A concurrent-collection regression exposed a misleading error on the losing
collector. A bounded retry of a server-rejected collect now reconciles the latest
head before trying again; applied receipts retain their original idempotency IDs.
Debug opt-in is retained across normal app launches and explicitly cleared by the
disable argument; Release continues to ignore that preference.

Final implementation handoff passed with 141 AppState tests, 267 persistence tests,
all routed style/documentation/script/build checks, and cheap CI gates. The two
earlier shell smoke tests passed. The finished Debug iPhone build reopened normally
with its Development sync preference retained. A subsequent Simulator product
trapped because the generic script runner disabled code signing; enabling the
target's entitlements alone was insufficient. The shared app-build arguments now
retain ad-hoc signing, with runner regression coverage. TestFlight build-switch and
contention changes require the additional verification recorded below.

The change-budget advisory flags the size of the replacement: explicit snapshot
coding, protocol state, reconciliation, the Apple adapter, and orchestration have
separate owners. Native graph mirroring was the smaller alternative, but cannot
provide coherent whole-save selection, atomic backup/claim receipts, or the approved
reset/account policy. The cloud tests each own a distinct persistence failure or
concurrency invariant; they do not duplicate general progression coverage.

The enabled unsigned device Release compile passed with
`TrinketCloudSyncEnabled=YES` and `TrinketCloudEnvironment=Production`. It was not
installed or uploaded. Development server checks use a temporary harness compiled
from the Persistence sources, with only its private zone name redirected to
disposable per-run verification zones. It neither replaces the real gameplay head
nor accesses Production. Actual concurrent requests exposed lockstep retries and
a successful eighth commit being reported as unavailable. Completion now returns
after installing an acknowledged save, and conflicting writers use bounded jitter
before retrying. The existing production regression exercises success on attempt
eight. Real concurrent collection subsequently granted the interval once.

The Development harness also passed simultaneous Collect and Upgrade after extending
the safe rejected-request retry to both production actions. The old-rate reward
and upgrade cost were each applied once. A real server claim was committed, its
reply deliberately lost, and the verifier process exited before local application.
Relaunch and disk reopen recovered the saved receipt and applied the reward once;
a second Collect returned no production. All 16 disposable verification zones were
removed after collecting evidence. The gameplay zone was untouched by this harness.
Evidence is retained outside Git at
`/Users/ryanmcintire/Documents/TrinketReleaseBackups/cloud-development-verification-20260913.json`.

Actual Apple-account switching/restriction, real network loss, and a full iCloud
quota have not been exercised on devices. Isolated tests cover signed-out/account
separation and failure/reconnect behavior. A second Apple account was requested for
the remaining live account-switch check. Production schema deployment, Production
execution, and a TestFlight upload remain intentionally unperformed under the
owner's latest scope.

Final verification passed across all 53 requested/adopted paths: 143 AppState tests,
268 Persistence tests, two UI shell smoke tests, 19 Python and three shell script
suites, style, docs, generation consistency, app build, and cheap CI gates. All nine
AppEnvironment tests also passed with Release compilation, including the build
default and local overrides. The latest unsigned cloud-enabled device Release build
passed and retained the expected `YES`/`Production` Info.plist values; it was not run
against Production. Scripted Simulator signing was verified by launching the normal
app with iCloud enabled: it remained running, used the same scoped account as the
iPhone, acknowledged reset count 1, and had no pending request. A subsequent normal
launch without arguments retained sync and stayed running with an empty outbox.

The newest signed Debug build installed on the iPhone. A final launch attempt was
blocked by the locked phone; the owner was asked to unlock/open it. Previous live
iPhone sync/reset evidence remains valid, but the last installed binary's foreground
launch is not yet confirmed. The execution plan stays active for the explicitly
remaining device and Production/TestFlight gates. No commit, push, upload, App Review
submission, or Production mutation was performed during this completion pass.

The review fixes now preserve intervening local progress before Homestead requests
and allow confirmed reset to recover durable storage from the memory fallback.
The scoped handoff passed with 270 Persistence tests. Live CloudKit Console
confirmed deployment of TrinketSaveHead, TrinketSaveBackup, and TrinketSaveOperation
to Production. Full Game availability was saved for the United States for the
owner's test account. App Store Connect shows Paid Apps Agreement pending user
information, no bank account, and missing W-9 tax information; the owner was asked
to complete those directly. Existing TestFlight is 0.1.0 (1); the next archive is
0.1.0 (2), with sync explicitly enabled for that archive.

The owner explicitly deferred StoreKit verification and Paid Apps Agreement
banking/tax completion. This does not block the authorized CloudKit-only internal
TestFlight update. Purchase verification remains pending until the agreement is Active.

The standalone signed archive uses an invocation-local
`-IDEBuildLocationStyle=Unique` with its isolated DerivedData path. Xcode's global
Custom/RelativeToWorkspace build-location preference otherwise redirected archive
products to the shared checkout output. Reusing compile-only SYMROOT/OBJROOT
overrides caused archive packaging to fail with a missing BuildProductsPath;
the archive invocation leaves its internal ArchiveIntermediates layout to Xcode.

The initial signed 0.1.0 (2) archive/export passed and its distribution payload
had CloudKit YES/Production, production APNs, and get-task-allow false. Apple's
upload validation rejected Xcode 27 beta (27A5228h) as unsupported. The internal
beta is being rebuilt with the installed pinned stable Xcode 26.6 (17F113), using
an invocation-local DEVELOPER_DIR; no system Xcode preference was changed. The
rejected upload did not publish a new TestFlight build.

Stable Xcode 26.6 (17F113) archive and export succeeded. The exported IPA was
verified as 0.1.0 (2), with CloudKit enabled, Production iCloud and APNs,
get-task-allow false, and beta reporting enabled. The internal-only upload
succeeded at 2026-09-13 09:40 PDT and entered Apple processing. Artifacts are in
`.DerivedData/TestFlight/build-2-stable/`. The source/project handoff passed,
including 270 Persistence tests. The owner installed build 1 on the Mac via the
existing invitation; Mac/iPhone Production verification awaits build 2 availability.

Build 2 reached Ready to Test, was assigned to Personal Testing (one internal
tester), and received the CloudKit test notes. Its export-compliance response
records only Apple-provided cryptography. Both the iPhone and Mac updated to
build 2. Production logs show successful zone/subscription creation, save upload,
and periodic record fetches; the first missing-zone response was followed by
successful creation. The owner confirmed that completed starter selection synced
from Mac to iPhone. The Mac completed Stage 1-1 and collected its reward.

Live testing also exposed a bounded starter-navigation refresh defect: the
onboarding flow initializes its navigation path once, so importing a hero choice
alone did not push the companion screen. ContentView now keys that flow to the
local save session generation, which changes on external imports but not own
acknowledgements. Build 3 carries this correction for verification.

Production bidirectional gameplay synchronization was verified with build 2:
the Mac selected Knight/Wolf, completed Stage 1-1 and claimed its reward; the
owner confirmed the iPhone received the progress, then recruited Bear there.
The Mac showed Bear unlocked and Stage 1-3 available, and retained Bear and the
Sapphire Ring after quitting and reopening. The build-3 starter-refresh change
passed source/project handoff and StarterOnboardingSmokeTests (one passing test).

Build 3 archived and exported with stable Xcode, passed distribution entitlement
inspection, and uploaded successfully at 2026-09-13 10:14 PDT. It contains the
starter-navigation refresh correction. Build 2 already established live Production
sync in both directions and a Mac relaunch check. StoreKit verification remains
explicitly deferred. Broader account, quota, offline contention, reset, and
Homestead Production edge-case coverage remain pre-release follow-up gates.

Build 3 finished Apple processing, its encryption declaration was saved, and
Personal Testing (one internal tester) was assigned automatically. The final
13-path handoff passed, including 270 Persistence tests and app compilation;
the onboarding smoke test passed separately. After the owner requested no more
iPhone interaction, only Safari release administration and documentation were
completed. Live device evidence remains from build 2; build 3's starter correction
has source/build/smoke coverage but has not been retested on the owner's iPhone.
