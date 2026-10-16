# Real-player coverage

Coverage authoring follows [Testing](Testing.md); local/hosted execution follows
[Verification](Verification.md). This portfolio supplements battle rules and save
transactions with real UI boundaries. It does not establish hardware or live
Apple-service readiness.

## Automated owners

| Player risk | Executable owner | Cadence |
|---|---|---|
| iOS 18 fallback controls, onboarding, combat, purchases/restore and durable saves | `player-coverage.sh ios18`: Profiles, registry Smoke, Full Game recovery, interrupted reward and Persistence package tests | Nightly/manual compatibility lane |
| Collected reward interrupted; duplicate Continue | Campaign `SmokeBattleTests` with a committed-reward checkpoint | Required routed push smoke |
| Live battle return; accepted claim termination; failed-write Leave; talent confirmation; normal-speed rapid cards/drag | `BattleLifecycleUITests`, AppState integration, BattleFeature card-play tests | Package checks plus nightly/manual FullUI |
| Voyage, Spires, Labyrinth inspector | `PlayModeNavigationUITests` | Nightly/manual FullUI |
| Homestead displayed cost/tier and reload; Haptics binding/reload | `HomesteadControlsUITests`, `OptionsUITests` | Nightly/manual FullUI |
| Pending approvals active/terminated, decline, cancellation, populated purchase recovery, revocation | `FullGamePurchaseUITests`, existing StoreKit session | Nightly/manual FullUI; ordinary purchase smoke remains required |
| Critical controls under native text sizes and Reduce Motion | `CriticalAccessibilityUITests` in Profiles | Nightly/manual Player coverage workflow |
| Real audio backend routing across battles and foreground | `AudioLifecycleUITests`; existing audio backend tests | Nightly/manual FullUI |
| Repeated UI ownership and progress | `RepeatedPlayUITests` in Soak | Weekly/manual Player coverage workflow |
| Populated schema-two migration, equipped gear, talents, maps, pinned offers and frozen cloud requests | `CloudSaveOutboxTests` | Persistence package checks |
| Account change during fetch and offline/retry behavior | `CloudSaveSyncTests`, isolated transport | Persistence package checks |
| Process exit before/after settlement and after remote commit before acknowledgement | `PlaythroughSweepTests`, `CloudProcessRecovery`, playthrough runner | Weekly/manual crash proof |

Existing BattleFeature tests retain draw-followup, overlapping-cast, finishing-tap,
RNG/reward immutability, and suspension protection. Existing AppState tests retain
failed writes, duplicate claims, stale callbacks, and talent-token ordering.
No per-mechanic UI matrix duplicates those owners.

## CI and profiles

[Player coverage workflow](../../.github/workflows/player-coverage.yml) uses the
verified toolchain. iOS 18 compatibility and critical settings profiles run nightly;
soak/recovery runs weekly. Manual dispatch selects compatibility, profiles, soak,
or all. Results are advisory for pushes, but requested-job failures produce a failed coverage aggregate. Requested FullUI also fails its advisory aggregate on failed, skipped, or unavailable execution; CI OK remains independent. Skipped
jobs mean unrequested portfolios, not executed coverage.

Run wrappers in CI or a bounded, task-relevant local diagnostic under
[execution limits](Verification.md#execution-limits). Local diagnostics require
`TRINKET_ALLOW_HEAVY_LOCAL=1`; separate user approval is not required to reproduce
or resolve a concrete failure. The CI invocations are:

```sh
./Scripts/player-coverage.sh ios18
./Scripts/player-coverage.sh compact
./Scripts/player-coverage.sh tablet
./Scripts/player-coverage.sh soak
```

Settings profiles request iPhone SE third generation on iOS 26 and iPad A16
(eleventh generation) on iOS 27. The compatibility lane separately requests iPhone
SE third generation on iOS 18. Missing types, incompatible/missing runtimes, and
missing native text controls fail visibly without fallback. Xcode 27's command-line
download rejects pre-26 runtimes ([FB24836279](https://developer.apple.com/forums/thread/847134)).
CI exports Apple's iOS 18.0 runtime with Xcode 26.6 on `macos-26`, transfers the
archive with one-day retention, then imports it on the verified Xcode 27 runner.
The disposable hosted compatibility runner removes its preinstalled runtimes
before transfer and deletes the archive after import to leave room for test
products. Its build and test simulator requests both require the iOS 18 profile.
Compilation and tests still use the verified toolchain. Other profiles install the
requested major's `.0` runtime with an explicit universal architecture variant
when absent. Every profile checks runtime availability and device compatibility
after preparation; failed provisioning fails the aggregate verdict.
Compatible products from successful exact-commit CI are reused;
missing or incompatible products rebuild, using the shared warm cache when no transfer
is available. One architecture's products are reused across settings and device profiles. All executions are serial on
their owned simulator lease. Test runs retain the build's shared results directory
so its validated build stamps remain available; each settings log and verdict
identifies its retained result directory.

Each settings and compatibility device runs native default text, native largest
accessibility text, and largest text with Reduce Motion. Native text settings are verified for every profile,
unchanged sizes are not reapplied, and the original size is restored once after the
device's profiles, even on failed journeys. Reduce Motion is selected through the native Settings app in the owned simulator
and restored after each class execution, including failed journeys. Both profile
methods verify the actual text-size and motion environment reached SwiftUI.
Simulator checks do not establish hardware evidence. Native audits run all seven
iOS audit types individually and exclude only the opt-in diagnostic label; no product
failures are blanket-suppressed. Audits record all their findings before restoring
the journey's stop-on-failure behavior; every recorded violation still fails its test.
Each native audit timeout receives one immediate
retry; a repeated timeout or any product
violation still fails the profile. Settings navigation waits for the retained Motion
screen, dismisses native search, and selects named back actions and destination
cells rather than matching titles or keyboard buttons. It scrolls toward retained
offscreen rows in either direction, including during settings restoration.

Settings-profile reward checks enter the existing victory fixture, then audit and tap
the real claim and verify next-stage access. Earned victory remains smoke-owned;
profiles avoid repeating combat across settings/device combinations.
Defeat and reward journeys scroll to their real actions before auditing and restore
their reachability afterward, since native text-size audits can move the viewport.
Each settings profile publishes its log and status before the next profile starts,
so a failed profile remains visible while independent checks continue.

Settings-profile Homestead checks audit and exercise the upgrade controls through the
visible tier change. Detailed resource debits and reload persistence remain owned by
`HomesteadControlsUITests`, avoiding repeated accounting across settings/device
combinations while retaining each combination's native accessibility evidence.

The iOS 18 lane also runs every registry-owned smoke class, the existing Full Game
purchase/recovery suite, committed-reward termination recovery, and the complete
Persistence package suite on the explicitly selected simulator. These cover
onboarding reload, tab navigation, manual combat and earned rewards, purchase access,
populated purchase recovery, and schema migration/reload without duplicating test bodies.
Purchase automation is required; an unavailable purchase runtime cannot count as
successful compatibility evidence. Stages run serially, retain failures while
continuing independent checks, and export screenshots for visual review. A passing
lane does not establish artwork readability, app-icon appearance, frame pacing,
thermal behavior, or memory readiness on older physical hardware; inspect those
before claiming release readiness.

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

The owned-purchase Restore journey checks that the native control preserves
populated local progress. StoreKit can recognize current entitlements before
Restore; this case does not establish restoration after reinstall or a live
service ownership loss.

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
- Actual populated beta-save upgrade and supported rollback.
- Live product loading, family ownership, approval delivery and reinstall restore
  under [Purchases](Purchases.md).
- Actual two-device/account/network/quota CloudKit scenarios under the
  [CloudKit readiness gates](CloudKitPreShipChecklist.md).

Ordinary builds retain local-only progress. This portfolio does not authorize
live accounts, publication, purchase-service changes, or wider sync enablement.
