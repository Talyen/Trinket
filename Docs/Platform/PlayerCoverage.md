# Real-player coverage

Coverage authoring follows [Testing](Testing.md); local/hosted execution follows
[Verification](Verification.md). This portfolio supplements battle rules and save
transactions with real UI boundaries. It does not establish hardware or live
Apple-service readiness.

## Automated owners

| Player risk | Executable owner | Cadence |
|---|---|---|
| Collected reward interrupted; duplicate Continue | Campaign `SmokeBattleTests` with a committed-reward checkpoint | Required routed push smoke |
| Normal-speed rapid cards/drag, background return and retreat | `SmokeBattleTests` | Required routed push smoke |
| Accepted claim termination; failed-write Leave; talent confirmation | `BattleLifecycleUITests`, AppState integration, BattleFeature card-play tests | Package checks plus nightly/manual FullUI |
| Voyage, Spires, Labyrinth inspector | `PlayModeNavigationUITests` | Nightly/manual FullUI |
| Homestead displayed cost/tier; Reset cancellation and confirmed erasure | `HomesteadControlsUITests`, `OptionsUITests`; Homestead durability in `PlayerHomesteadStoreTests` | Nightly/manual FullUI plus package checks |
| Pending approvals active/terminated, decline, populated purchase recovery, revocation | `FullGamePurchaseUITests`; cancellation in `FullGameStoreTests` | Nightly/manual FullUI plus package checks; ordinary purchase smoke remains required |
| Reward claim, Campaign return, and next stage | `RewardReturnUITests` on compact iOS 26 and iPadOS 27 | Independent nightly/manual Player coverage jobs |
| Critical controls and reward claim → return → next stage under native text sizes and Reduce Motion | `CriticalAccessibilityUITests` in Profiles on iOS and iPadOS 26 and 27 | Nightly/manual Player coverage workflow |
| Real audio backend routing through battle, foreground and relaunch | `AudioLifecycleUITests`; existing audio backend tests | Nightly/manual FullUI |
| Repeated UI ownership and progress | `RepeatedPlayUITests` in Soak | Weekly/manual Player coverage workflow |
| Populated schema-two migration, equipped gear, talents, maps, pinned offers and frozen cloud requests | `CloudSaveOutboxTests` | Persistence package checks |
| Account change during fetch and offline/retry behavior | `CloudSaveSyncTests`, isolated transport | Persistence package checks |
| Process exit before/after settlement and after remote commit before acknowledgement | `PlaythroughSweepTests`, `CloudProcessRecovery`, playthrough runner | Weekly/manual crash proof |

Required functional Smoke, exhaustive FullUI and exact-build diagnostics all use
the qualified iPhone 17 Pro / iOS 26.2 (23C54) baseline. Required purchase smoke
checks a real Options purchase and unlocked access; FullUI retains the complete
campaign/purchase/recruited-Warlock/battle journey and every recovery case.
Exhaustive UI runs independently of compilation/smoke using exact-commit products.
Native settings profiles cover additional OS and device combinations. The known
iOS 27 local StoreKit denial defect must not be worked around by granting or filtering signed
ownership, or by dropping the denial/retry assertions; see
[StoreKit qualification](Release.md#testflight-troubleshooting).

Existing BattleFeature tests retain draw-followup, overlapping-cast, finishing-tap,
RNG/reward immutability, and suspension protection. Existing AppState tests retain
failed writes, duplicate claims, stale callbacks, and talent-token ordering.
No per-mechanic UI matrix duplicates those owners.

## CI and profiles

[Player coverage workflow](../../.github/workflows/player-coverage.yml) uses the
verified toolchain. Hosted simulator coverage starts at iOS and iPadOS 26. The
[App Store compatibility floor](ApplePlatformReference.md#platform-support) remains
18.0. Critical settings profiles run nightly. Sunday's nightly run retains the
complete native audit matrix, and the separate weekly run owns soak/recovery.
Manual dispatch selects profiles, soak, or all. A requested job must succeed for
its coverage aggregate to pass. CI OK remains independent of the player coverage
and FullUI aggregates.

[Verification](Verification.md#execution-limits) owns local authorization, selectors
and resource limits, including its single focused diagnostic exception. The
following commands select hosted portfolios:

```sh
./Scripts/player-coverage.sh compact
./Scripts/player-coverage.sh tablet26
./Scripts/player-coverage.sh tablet
./Scripts/player-coverage.sh duo
./Scripts/player-coverage.sh compact reward-return
./Scripts/player-coverage.sh tablet reward-return
./Scripts/player-coverage.sh duo rotation
./Scripts/player-coverage.sh soak
```

Profiles cover iPhone SE third generation on iOS 26, iPad A16 (eleventh generation)
on iPadOS 26 and 27, and iPhone Duo on iOS 27.1 or later in that major. Missing or
incompatible devices, runtimes or native settings fail the requested profile.
Within a requested major, selection uses the newest installed runtime compatible
with that device; exact OS-version and build requests remain exact. A newer Duo-only
runtime must not prevent the iPad profile from using its compatible runtime.
When iOS 26 is missing, provisioning requests build `23C54` (iOS 26.2), matching the
purchase-qualification runtime. Requesting the semantic version alone can download
a different build. All functional UI tests pin that build during simulator selection.
Read-only simulator inventory queries retry one 30-second timeout. Exhausted
queries still fail; native settings changes are not automatically repeated.
Simulator identity is recorded after the serial tests and settings restoration,
so the cold-boot inventory query cannot prevent those tests from starting.
Missing identity still fails the lane and retains the executed profile receipts.

Reward return, the four native settings profiles, and Duo rotation run as separate
serial jobs on fresh hosted runners. A stalled CoreSimulator service in one job
must not prevent another check from running. Settings stay serial within each device, each artifact
names its profile, and prerequisite failures retain structured diagnostics.

Each device exercises native default text, largest accessibility text, and largest
text with Reduce Motion. Verify those settings actually reach SwiftUI and restore
the original settings even after failure. A failed prerequisite is configuration
failure, not completed product coverage.

On six nightly runs per week, all interactions and actual native-environment checks
remain on every settings profile, while all seven native audit types run on each
device's largest-text profile without Reduce Motion. This runs one third of the
full audit matrix before retries. Sunday's nightly run, manual dispatch and direct
scripts retain the full native audit matrix. Only sampled CI runs explicitly request
`TRINKET_COVERAGE_AUDIT_POLICY=representative`; the script default is `all`.
Each profile receipt records whether native audits were requested. Product violations
still fail without blanket suppression.

Profiles exercise the real reward claim/next-stage access and visible Homestead tier
change. Earned combat stays smoke-owned; displayed debits belong to
`HomesteadControlsUITests`, with durable costs/tiers in `PlayerHomesteadStoreTests`.
The standalone reward test uses the same claim and navigation assertions without
opening Settings or running native audits. The separate Duo rotation job waits
for the app window to resize, then checks retained hand, usable controls and a
card play. Folding during held input, inspection, automatic
casts or reward reveal still needs managed Device Hub inspection.

Registry Smoke, Full Game purchase and recovery, committed-reward termination
recovery, and the Persistence package suite run through their CI owners above.
Physical-device artwork, icon, frame, memory and thermal review remain separate
release checks. [Profile execution](VerificationInternals.md#player-profile-execution)
owns runtime preparation, product reuse, native-settings mechanics and diagnostics.

Weekly UI soak uses one audio-enabled store for twenty Contracts, visiting
Collection/Homestead and backgrounding every fifth cycle. Headless careers cover
Campaign, Contracts, Labyrinth and Spires at seeds 101–105 with ten attempts;
odd seeds use setup-aware policy and even seeds random policy. Ordinary careers run
in one serial XCTest worker with separate mode/policy reports, retaining all
twenty careers and their independent stores, contexts, seeds, and journals. Each career
closes its transient state before the next starts. Batch reports label per-career
body time separately from the shared process wall time. The external watchdog retains
a per-career deadline plus a bounded overall deadline. Interruption, recovery, and
replay checks retain separate processes. Invariants, not
victory rates, determine acceptance. UI soak accepts either outcome and verifies that only victories add their displayed Contract claim. Raw scenario manifests permit replay.

## Duo visual qualification

Apply the [screen-wide native bar policy](ApplePlatformReference.md#content-beside-native-bars)
to the closed/open portrait and landscape matrix. Retain the active display's
screenshot and actual app-window dimensions; the inactive outer display can be
black while the inner display hosts the app. A successful pose command or device
orientation value alone does not establish that the window resized. Keep the
rotation journey's actual-geometry assertion intact when tooling cannot drive it.
Use [Duo display routing](SimulatorOperations.md#duo-display-routing) to distinguish
inactive-display capture/input from app failures.

For interrupted input, first demonstrate that touch reaches the active display.
Retain the touch interval and a recording showing held artwork before the real
display transition; an issued drag command alone does not prove overlap with the
fold. Compare the hand and process before/after, then exercise fresh card play.
For rewards, compare the named fixture's saved award and claim receipt after one
claim. A visible button alone does not establish successful or single settlement.

Inspect hero extension and upper portrait framing, every horizontal shelf endpoint,
vertical-grid rightmost cells, pinned cost/action docks, and map/talent inspectors.
Repeat with long localized labels and native largest text, then compare ordinary
iPhone and iPad layouts. Exercise folding during dragging, inspection, Auto Battle,
automatic casts and reward reveal; verify cancellation, retained navigation and no
duplicate commands or claims. A source review, successful build, subset of captures
or lightweight handoff cannot close this qualification. Hosted package tests and
relevant UI/profile results remain required for the exact revision.

## Evidence and remaining gates

Retain screenshots, compact diagnostics, actual settings/device/runtime/toolchain and
commit identity for passing profiles. Failed or unclassified runs retain full result
bundles; screenshot export failures also retain the original bundle. Soak retains raw
interrupted stores, journals, remote test state and replay reports. Hosted evidence
retention and the read-only command for checking GitHub's repository cap live in
[output retention](../../Scripts/Reference.md#output-retention). Download evidence
needed beyond its actual expiry before it is removed. A failed profile retains its
verdict while other settings execute. Soak failure does not hide the subsequent career/recovery
verdicts. Archive interrupted inputs before opening recovery copies.

The terminated-approval journey verifies startup entitlement recognition and
preservation of Gold and completed stages without tapping Restore. The separate failed-Restore
journey verifies usable recovery after a native restore error. Neither establishes
successful ownership restoration after reinstall or live service ownership loss;
those remain live purchase-readiness gates.

Audio observations prove real backend starts and buffer scheduling, and detect
errors/duplicate same-track ownership. They cannot prove audible output. Process
footprint observations are diagnostic, without simulator shipping thresholds.
Preserve artwork pins and full audio/visual behavior.

Schema-two fixtures prove the authored historical graph upgrades and survives
mutations/reload, including cloud-disabled reopening. They do not prove an
installed beta update or rollback. The subprocess cloud transport persists a
disposable remote head/receipt atomically and exits before acknowledgement; it
uses the production coordinator without contacting CloudKit.

Automation implementation and lightweight handoff do not confirm Swift compilation
or UI execution. Record hosted conclusions for the exact revision before claiming
these journeys passed.

The following live evidence remains deferred to a separately requested pass:

- Phone lock/call interruptions, Bluetooth routes, and audible audio recovery.
- Extended device memory, thermal, energy and Low Power Mode behavior.
- VoiceOver task completion and visual review of critical settings/screens.
- Rendered battle feedback, including floating feedback, and Duo touch and precise
  cast-boundary interactions when inspection tools can exercise them.
- Actual populated beta-save upgrade and supported rollback.
- Live product loading, family ownership, approval delivery and reinstall restore
  under [Purchases](Purchases.md).
- Actual two-device/account/network/quota CloudKit scenarios under the
  [CloudKit readiness gates](CloudKitPreShipChecklist.md).

Ordinary builds enable iCloud sync. This portfolio does not establish live CloudKit
or purchase-service behavior or authorize publication.
