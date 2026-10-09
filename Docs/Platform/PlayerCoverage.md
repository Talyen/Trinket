# Real-player coverage

Coverage authoring follows [Testing](Testing.md); local/hosted execution follows
[Verification](Verification.md). This portfolio supplements battle rules and save
transactions with real UI boundaries. It does not establish hardware or live
Apple-service readiness.

## Automated owners

| Player risk | Executable owner | Cadence |
|---|---|---|
| Collected reward interrupted; duplicate Continue | Campaign `SmokeBattleTests` with a committed-reward checkpoint | Required routed push smoke |
| Live battle return; accepted claim termination; failed-write Leave; talent confirmation; normal-speed rapid cards/drag | `BattleLifecycleUITests`, AppState integration, BattleFeature card-play tests | Package checks plus nightly/manual FullUI |
| Voyage, Spires, Labyrinth inspector | `PlayModeNavigationUITests` | Nightly/manual FullUI |
| Homestead displayed cost/tier and reload; Haptics binding/reload | `HomesteadControlsUITests`, `OptionsUITests` | Nightly/manual FullUI |
| Pending approvals active/terminated, decline, cancellation, populated restore, revocation | `FullGamePurchaseUITests`, existing StoreKit session | Nightly/manual FullUI; ordinary purchase smoke remains required |
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
verified toolchain. Critical settings profiles run nightly; soak/recovery runs
weekly. Manual dispatch selects profiles, soak, or both. Results are advisory for
pushes, but requested-job failures produce a failed coverage aggregate. Requested FullUI also fails its advisory aggregate on failed, skipped, or unavailable execution; CI OK remains independent. Skipped
jobs mean unrequested portfolios, not executed coverage.

Run wrappers only in CI or an expressly requested local diagnostic:

```sh
./Scripts/player-coverage.sh compact
./Scripts/player-coverage.sh tablet
./Scripts/player-coverage.sh soak
```

Profiles request iPhone SE third generation on iOS 26 and iPad A16 (eleventh
generation) on iOS 27. Missing types, incompatible/missing runtimes, and missing
native text controls fail visibly without fallback. CI installs the requested
major's `.0` runtime when that major is absent, then checks availability and device
compatibility again. One architecture's products are reused across settings and
device profiles. All executions are serial on
their owned simulator lease. Test runs retain the build's shared results directory
so its validated build stamps remain available; each settings log and verdict
identifies its retained result directory.

Each device runs native default text, native largest accessibility text, and
largest text with Reduce Motion. Native text settings are verified and restored
even on failed journeys. Reduce Motion is selected through the native Settings app in the owned simulator
and restored after each test. The app probe verifies largest text and the real
motion environment. Simulator checks do not establish hardware evidence. Native audits exclude only the opt-in diagnostic
label; no product failures are blanket-suppressed.

Weekly UI soak uses one audio-enabled store for twenty Contracts, visiting
Collection/Homestead and backgrounding every fifth cycle. Headless careers cover
Campaign, Contracts, Labyrinth and Spires at seeds 101–105 with ten attempts;
odd seeds use setup-aware policy and even seeds random policy. Invariants, not
victory rates, determine acceptance. UI soak accepts either outcome and verifies that only victories add their displayed Contract claim. Raw scenario manifests permit replay.

## Evidence and remaining gates

Retain result bundles, screenshots, actual settings/device/runtime/toolchain and
commit identity, raw interrupted stores, journals, remote test state and replay
reports with fourteen-day workflow retention requests. GitHub currently caps this
repository's uploads at one day; download evidence needed beyond that cap until
the repository setting is raised. A failed profile retains its verdict while other
settings execute. Soak failure does not hide the subsequent career/recovery
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
