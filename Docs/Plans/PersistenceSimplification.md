---
type: execution-plan
status: active
created: 2026-09-10
updated: 2026-09-10
expires: 2026-09-24
---

# Preserve saves and simplify storage recovery

## Approval status and objective

Revised after the user's September 10 clarification and approved for execution.
The product goal is to prevent persistence failures and handle proven
recoverable conditions automatically, without asking players to diagnose storage,
acknowledge technical failures, free space, or reinstall the game.

The prior recommendation to continue with a fresh in-memory game and warn that
progress will be lost is withdrawn. Silently doing the same thing would also fail
the goal: apparent gameplay success must not conceal disposable progression.

There is no demonstrated real-device save-open failure in this investigation.
The immediate confirmed defect is cleanup of extensionless custom store paths;
Trinket's normal store filename has an extension. Treat this as bounded cleanup,
not evidence of widespread save loss. Do not build a general recovery system on
the strength of a malformed-file test.

## Random selection and scope

Python `random.Random(2497221508).randrange(10)` returned zero-based index 7.
Candidates were sorted directories containing `Packages/*/Package.swift`, followed
by `Scripts`: BattleEngine, TrinketAppState, TrinketBattleFeature, TrinketContent,
TrinketCore, TrinketDesignSystem, TrinketFeatureSupport, TrinketPersistence,
TrinketTestSupport, Scripts. The initial directory enumeration accidentally included
`.build`; it was corrected to authored packages and the same seed reused.

Selected owner: `Packages/TrinketPersistence`. Investigation stopped after finding
the recovery and cleanup issues below. Follow-up reads were limited to callers,
existing tests, and the warning surface. This is not a whole-package clean bill of
health. Existing FeatureSupport, TestSupport, and script edits remain untouched.

## Evidence and findings

### 1. Opening a save can delete progress without establishing corruption

[ModelContainerBootstrap.swift](../../Packages/TrinketPersistence/Sources/TrinketPersistence/ModelContainerBootstrap.swift)
lines 26–49 catch every primary-open error, delete the configured store family,
and retry. There is no error classification or preservation step.
[PlayerSaveStore.swift](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift)
passes `deleteStoreOnFailure: true` at its sole bootstrap call.
[PlayerSaveStoreConfiguration.swift](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStoreConfiguration.swift)
supplies a recovery URL for local stores, including the default cloud-disabled
store. [AppEnvironment.swift](../../Packages/TrinketAppState/Sources/TrinketAppState/App/AppEnvironment.swift)
disables CloudKit unless explicitly enabled, so this path is relevant to normal
local play, not only test stores.

Verified: the unconditional destructive branch exists and is reachable by the
normal local configuration. Inference: an open failure unrelated to corrupt bytes
could destroy recoverable progress if deletion succeeds. No actual player loss,
low-disk failure, or migration failure was reproduced. The existing `corrupt store
recovers by deleting and recreating` test proves the current wipe policy is
intentional coverage, so changing it requires approval rather than relabeling it
as a behavior-preserving refactor.

### 2. Extensionless cleanup targets the wrong files

The same file, lines 70–81, strips the path extension and rebuilds sidecars as
extensions. For `/.../save`, it targets `save.wal`, `save.shm`, and `save.journal`;
SQLite sidecars use `save-wal`, `save-shm`, and `save-journal`.

A temporary Swift probe ran the exact `deleteStoreFiles` function extracted from
the repository against sentinel files. It exited successfully with these files
remaining: `save-journal`, `save-shm`, `save-wal`. It removed both `save` and the
unrelated `save.wal` sentinel. No real store was touched; probe files were removed.
The public initializer accepts arbitrary store URLs, although the default filename
has an extension. Existing cleanup coverage uses only a `.sqlite` filename.

### 3. Recovery complexity and test cost follow from the destructive branch

Bootstrap has one caller but carries a configurable deletion switch, recovery URL,
repeated container construction, a recovered-after-deletion result flag, and a
matching public store flag. AppState consumes that flag solely to trigger the
same warning already used for degraded persistence. Removing automatic deletion
allows this entire branch and its state to disappear together.

The sidecar cleanup test opens a SwiftData store just to test file removal. Plain
temporary files can exercise the same contract more cheaply and add the missing
filename boundaries. This is a clear setup reduction, not a measured speed claim.

## Apple guidance and practical relevance

- Apple says `ModelContainer` coordinates storage and performs automatic schema
  migration; supply a `SchemaMigrationPlan` only when the changes exceed automatic
  migration's capabilities. Our first responsibility is correct schemas and
  upgrade coverage, not replacing SwiftData's storage machinery.
  [Apple ModelContainer documentation](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- Apple's Core Data documentation lists full disks, permission problems, and
  corrupted stores as possible persistence errors. These are real platform
  categories, not evidence of their occurrence in Trinket or of their frequency.
  [Apple persistent store behaviors](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/PersistentStoreFeatures.html)
- Protected files can be unavailable while an iPhone is locked, depending on file
  protection class. Apple exposes availability notifications. This only justifies
  a lifecycle handler if Trinket's actual file protection and execution lifecycle
  make it applicable; do not add a hypothetical background-launch subsystem.
  [Apple protected-data availability](https://developer.apple.com/documentation/uikit/uiapplication/isprotecteddataavailable)

Ordinary local saving does not require internet access. A missing connection alone
is not a reason to recreate a local save. No evidence here calls for changing
SwiftData, enabling CloudKit, maintaining a second database, or adding backups.

No framework can guarantee successful durable writes when storage remains
unavailable, or reconstruct destroyed data without a valid surviving copy. The
product aspiration does not establish that every failure has an invisible repair.
Do not describe a permanent stall, crash, silent reset, or unsaved session as
successful automatic recovery.

## Revised plan

### A. Bounded cleanup with direct evidence

1. Correct sidecar targeting by appending `-wal`, `-shm`, and `-journal` to the
   complete store filename. Retain unrelated sibling files. Do not change reset
   eligibility, store URL precedence, or schema behavior.
2. Replace the cleanup test's SwiftData setup with temporary sentinel files.
   Parameterize `.sqlite`, `.store`, and extensionless paths; assert deletion of
   the store family, preservation of unrelated files, and safe repeated cleanup.
   Keep the existing explicit reset and duplicate-root reload tests.
3. Correct the nearby test ownership table: `PlayerSaveSchemaMigrationTests`
   lives in its own file. No additional documentation sweep.

### B. Prevention check before any recovery redesign

1. Trace actual production startup and save failure ownership, including both
   fallback layers. The follow-up read found a second fallback in
   [TrinketApp.swift](../../Trinket/App/TrinketApp.swift): any AppState bootstrap
   error causes another attempt with an explicitly in-memory PlayerSaveStore.
   That explicit configuration does not set the store's degraded flag. Thus the
   previous plan's package-only fallback change was incomplete. Do not replace
   one fallback while leaving the other to mask failure.
2. Check migration evidence against the actual supported upgrade window. Existing
   migration tests construct variants using current model definitions; establish
   which released schemas must be supported before proposing archived fixtures or
   explicit migration stages. Missing a custom migration plan by itself is not a
   defect because SwiftData supports automatic migration.
3. Verify the real store's protection/lifecycle configuration before adopting a
   protected-data handler. Inspect existing write-failure compensation and callers
   only far enough to establish whether unsuccessful actions can appear successful.
   Do not redesign transaction semantics without a reproduced consequence.
4. For any confirmed failure, record the trigger, underlying error, relevant
   production path, cheapest reproduction, and specific remedy. Use temporary
   test stores; never fill the user's disk or manipulate their real save. Distinguish
   injected failures from observed failures on an iPhone. If no additional defect
   is established, stop and report that outcome.

### C. Concrete startup proposal — awaiting the player-visible decision

**Proposed player outcome:** if opening the real save fails, show a stationary
screen reading **“Trinket can’t open right now.”** Use the existing native
unavailable-view layout and game background. Show no database/error details,
troubleshooting instructions, acknowledgement alert, reset button, or loading
spinner. Do not start a fresh game. A normal subsequent launch makes a new attempt
against the untouched save. Do not add automatic polling or an unlock observer
without evidence that either would help.

**Material tradeoff requiring explicit approval:** the player cannot play during
this condition. A permanent schema/storage problem may require an app update or
an external condition to change. This proposal preserves progress and avoids
misleading play, but does not claim an invisible cure or perpetual availability.
It satisfies the request to keep technical mishaps out of player-facing copy;
the remaining approval is specifically for blocking play in this exceptional case.

Implementation after that approval:

1. Make `PlayerSaveStore` open its configured SwiftData container or throw.
   Remove automatic deletion/recreation and both in-memory fallback layers,
   including the app-level fallback in `TrinketApp.init`. Explicit in-memory
   stores remain available for previews/tests and intentional test launch options.
2. Delete the bootstrap wrapper if opening is reduced to one call. Move explicit
   reset file cleanup into `PlayerSaveStoreConfiguration`; retain its fixed
   filename behavior. Remove recovery-only parameters and result flags after
   checking consumers. Keep the existing throwing public store initializer;
   add no public startup abstraction or persistence backend protocol.
3. Ensure failure to create/save a new initial root also throws instead of
   launching an unsaved fresh game. Review startup repair saves on the same basis.
   Preserve established runtime mutation compensation; this is not a transaction
   redesign or a guarantee about future writes.
4. Keep app construction and the terminal unavailable state in the existing app
   entry file. Replace its current technical failure/reinstall copy with the
   proposed sentence. Remove the recovery acknowledgement alert and obsolete
   startup status flags. Treat runtime Options status removal separately from
   startup if deleting it would hide unresolved action failures.
5. Replace wipe-policy tests with an invalid-store preservation test: opening
   throws, original bytes survive, no replacement durable game appears. Keep
   real reload/migration/reset tests. Use a narrow internal construction seam only
   if a consequential valid-store failure regression cannot otherwise be tested.
   Do not add an error simulation framework.
6. Reroute all changed/deleted paths and execute Persistence/AppState tests, app
   compile, and the selected launch smoke. Verify the exceptional screen via an
   isolated test fixture; never alter a real save. Load simulator guidance for
   that inspection and preserve launch artwork pins.

## Prevention-check findings (September 10)

- Current `project.yml` declares no background modes, and the entitlement file is
  empty. The app has no explicit file-protection overrides or protected-data
  handlers. A physical device's actual file protection was not measured, so this
  is evidence against adding new lifecycle machinery, not proof that access can
  never fail. Local-only posture is canonical in CloudKitPreShipChecklist.
- `AppEnvironment` persists immediately by default; deferred persistence requires
  an explicit launch argument. Scene inactive/background paths already flush
  pending writes. No additional timer or background task is justified here.
- Sampled consequential actions already respect failed writes: battle completion
  only ends after persistence succeeds; Shop only marks an offer sold after a
  successful write. Existing store tests cover rollback, retry, deferred flush,
  and subsequent reload. No new action/transaction defect was established.
- The only release tag is `v0.1.0`, whose file store was deliberately removed in
  commit `b6dc4949`. The September 10 archived talent plan records approval with
  no current players or saves. This supplies repository evidence against creating
  legacy file-store migration scaffolding now; it is not independent App Store
  distribution telemetry. Preserve current migration/reload coverage and establish
  immutable release schemas when a real consumer window exists.
- Both startup fallback layers are confirmed by source. The app-level fallback
  uses an explicitly in-memory store and can leave degraded status false. No real
  iPhone failure was reproduced. This is a reason to simplify the combined path
  after the explicit outcome decision, not to invent additional recovery layers.

## Verification

For A, run `./Scripts/handoff.sh --isolate --paths <all changed files>`; preserve
existing reset → disk reload coverage. Do not launch SwiftData merely to verify
filename operations. For any later approved startup work, reroute the complete
path union, load applicable architect/apple-design skills, and run selected
Persistence/AppState checks plus routed app compile and targeted UI verification.

Keep substantive migration/reload coverage. Replace a policy test only alongside
its approved replacement behavior. No test retirement may conceal data loss.
Review final changes and document actual checks and limitations; no numerical
performance gain is claimed. Archive this plan when its approved scope is complete.

## Scope and execution status

A is implemented and B is complete. C is now concrete and awaits only the
exceptional player-visible outcome decision. The changed files are bootstrap's
cleanup function, the existing cleanup tests, the persistence test README, and
this plan. No technology change,
CloudKit enablement, gameplay rebalance, or general recovery framework is proposed.

- [x] Randomly select subsystem and record workspace state.
- [x] Reproduce the custom-path cleanup defect.
- [x] Check Apple guidance and revise the initial recovery recommendation.
- [x] Approve revised scope before implementation.
- [x] Complete bounded prevention check and report only established findings.
- [x] Implement approved cleanup and documentation correction.
- [ ] Obtain the exceptional startup outcome decision and implement C if approved.
- [ ] Complete routed verification, final diff review, and plan archival.

## Validation to date

The exact extracted cleanup function reproduced the filename defect in temporary
files before the fix. Path-scoped isolated handoff passed after the fix: style,
documentation, module boundaries, and cheap CI slices; **260 Persistence tests
passed, zero failed or skipped**, including the three filename cases and existing
migration/reset/reload coverage. No real-device storage failure or shipped
migration failure was reproduced. Startup behavior is unchanged pending C.
