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
| Homestead displayed cost/tier and reload; reset cancellation and confirmed erasure | `HomesteadControlsUITests`, `OptionsUITests` | Nightly/manual FullUI |
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
Sunday's nightly run retains the complete native audit matrix; the separate weekly
run owns soak/recovery. Manual dispatch selects
compatibility, profiles, soak, or all. Results are advisory for pushes, but requested-job failures produce a failed coverage aggregate. Requested FullUI also fails its advisory aggregate on failed, skipped, or unavailable execution; CI OK remains independent. Skipped
jobs mean unrequested portfolios, not executed coverage.

Run wrappers in CI or a bounded, task-relevant local diagnostic under
[execution limits](Verification.md#execution-limits). Local diagnostics require
`TRINKET_ALLOW_HEAVY_LOCAL=1`; separate user approval is not required to reproduce
or resolve a concrete failure. The CI invocations are:

```sh
./Scripts/player-coverage.sh ios18
./Scripts/player-coverage.sh compact
./Scripts/player-coverage.sh tablet
./Scripts/player-coverage.sh duo
./Scripts/player-coverage.sh soak
```

Profiles cover iPhone SE third generation on iOS 26, iPad A16 (eleventh generation)
on iOS 27, and iPhone Duo on iOS 27.1 or later in that major. The compatibility lane
uses iPhone SE third generation on iOS 18. Missing or incompatible devices, runtimes
or native settings fail visibly; there is no substitute profile.

Each device exercises native default text, largest accessibility text, and largest
text with Reduce Motion. Verify those settings actually reach SwiftUI and restore
the original settings even after failure. A failed prerequisite is configuration
failure, not completed product coverage.

On six nightly runs per week, all interactions and actual native-environment checks
remain on every settings profile, while all seven native audit types run on each
device's largest-text profile without Reduce Motion. This reduces audit calls from
420 to 140 before retries; settings-specific violations outside that profile may
be detected later. Sunday's nightly run, manual dispatch and direct scripts retain
the full native audit matrix. Only sampled CI runs explicitly request
`TRINKET_COVERAGE_AUDIT_POLICY=representative`; the script default is `all`.
Each profile receipt records whether native audits were requested. Product violations
still fail without blanket suppression.

Profiles exercise the real reward claim/next-stage access and visible Homestead tier
change. Earned combat stays smoke-owned; detailed resource debits and reload stay
with `HomesteadControlsUITests`. The Duo profile also runs the focused rotation
journey once after settings restoration, checking actual geometry, retained hand,
usable controls and a card play. Folding during held input, inspection, automatic
casts or reward reveal still needs managed Device Hub inspection.

The iOS 18 lane additionally runs every registry Smoke class, Full Game purchase/
recovery, committed-reward termination recovery and the Persistence package suite.
Missing purchase execution cannot count as compatibility success. Passing automation
still needs physical-device artwork, icon, frame, memory and thermal review before
release-readiness claims. [Profile execution](VerificationInternals.md#player-profile-execution)
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

The populated-purchase journey verifies startup entitlement recognition and
preservation of local progress without tapping Restore. The separate failed-Restore
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
- Actual populated beta-save upgrade and supported rollback.
- Live product loading, family ownership, approval delivery and reinstall restore
  under [Purchases](Purchases.md).
- Actual two-device/account/network/quota CloudKit scenarios under the
  [CloudKit readiness gates](CloudKitPreShipChecklist.md).

Ordinary builds retain local-only progress. This portfolio does not authorize
live accounts, publication, purchase-service changes, or wider sync enablement.
