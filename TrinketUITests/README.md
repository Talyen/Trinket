# TrinketUITests

UI test mechanics for Trinket. Agent workflow: `AGENTS.md`. Semantic test
ownership and keep/drop rules: [`Docs/Platform/Testing.md`](../Docs/Platform/Testing.md).
UI selector constants live in `Packages/TrinketFeatureSupport`. “Exhaustive” names
the existing suite; use the [Testing rubric](../Docs/Platform/Testing.md#ui-keep-drop-rubric)
for coverage and retirement decisions.

## Layout

| Area | Path | When |
|------|------|------|
| Smoke | `Smoke/` sources; `Smoke.xctestplan` at repo root | CI `test.sh smoke` (registry-defined classes); runs on the build runner without a product transfer |
| Exhaustive | `Play/`, `Collection/`, `Battle/` | Advisory nightly/dispatch CI, runs all registered classes on one runner; includes StoreKit recovery; deliberate local diagnostics follow [Verification.md](../Docs/Platform/Verification.md#local-simulator-budget) |
| Performance | `Performance/`, `BattlePerformance.xctestplan` (repo root) | Manual CI `performance.yml` / `performance.sh` investigations; outside routine smoke |
| Profiles | `Profiles/`; generated `Profiles.xctestplan` | Nightly/manual compact iOS 26 phone, portrait iOS 27 iPad, iOS 27.1+ Duo, and the iOS 18 compatibility phone; three settings configurations per device |
| Soak | `Soak/`; generated `Soak.xctestplan` | Weekly/manual audio-enabled twenty-Contract career; outside routine FullUI |
| Support | `Support/` | Shared launch and StoreKit fixtures; shared journeys (`PlayScreen`, `BattleScreen`, `TabBar`, …) |

Author smoke and exhaustive membership once in `Scripts/config/ui-tests.tsv`.
Each row supplies suite, smoke routing key (empty for other suites), and class.
Selections follow registry row order. For UI membership changes alone, run
`python3 Scripts/check-testplan-sync.py --generate`; it updates only `selectedTests`
in the UI plans, preserving other settings and avoiding content-inventory compilation.
Full project generation also invokes this generator. Profiles and Soak plans are generated from the FullUI plan settings when first created. CI reads all FullUI classes through `check-testplan-sync.py --classes FullUI` and serial
smoke filters through `--classes Smoke`; local smoke routing uses the same rows. Add, remove, or move registrations with the source
class, then regenerate the plans. The checker rejects missing/duplicate classes, duplicate
routing keys, stale plan selections, and workflows bypassing registry selections.
Focused runs require every requested filter and at least one executed test in the
result tree. When export stalls, terminal per-test log records provide that proof;
a suite summary alone does not. Documented individual skips remain visible in results. CI requires a runtime that
executes the Full Game purchase journey; the documented iOS 26.5 purchase skip
is local-only.

## Launch args

Defined as `TestLaunchArg` in `Support/TrinketUITestCase.swift` and parsed by
`AppEnvironment`. Helpers include `allForScreen`, `allForTab`, `allForBattle`,
`allForMidBattle`, and
`completedStages`. Use the source type for the complete, current catalog.

**Default smoke args:** `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`.

`launchApp` waits for the launch artwork cover to finish before returning, so
screen-readiness assertions measure their destination rather than cold artwork
preparation. Its bounded timeout lives in `TrinketUITestCase`; a warmup timeout
fails explicitly instead of being reported as a missing destination.
The cover query targets `otherElements` rather than every accessibility element.
Only the exact XCTest system snapshot timeout during this preparation phase is
marked for one CI infrastructure retry. Gameplay query timeouts and readiness
assertions remain failures. Failure attachments record the phase and runtime;
snapshot failures omit another hierarchy query. Both original and retry evidence
remain available in the hosted diagnostics artifact after successful recovery.

Common screen-entry arguments are `-launch-screen` and `-selectedTab`; state
seeding uses `-completed-stages`, `-starting-gold`, and the reset/cloud-sync
flags. Performance-only frame metrics are opt-in and never belong to smoke.

Keep default launch args unless testing persistence. Prefer `AccessibilityID`
selectors and assert with `assertExists`; use visible text only when it is the
product contract. UI tests tap tab labels, not `AppTab` raw values. Sheet dismissal names the expected
sheet identifier and waits for it to disappear. Native sheet drag dismissal is
used where the screen intentionally has no Close control.

Launch waits for the loading cover to disappear and for app controls to appear;
cover absence alone does not prove an interactive surface is ready.
Normal control taps share one readiness predicate and require existence,
enablement, a finite nonempty frame, and hittability. Check geometry before
hittability because sheet transitions can temporarily expose invalid frames.
Use explicit
coordinate gestures only for gesture tests or a demonstrated automation limitation.
On iOS 18, the visible native Battle Menu reports itself as unhittable. Its helper
validates finite onscreen bounds before a center tap and requires the real Combat
Log menu action to appear; iOS 26+ retains ordinary readiness taps.
The transparent frame-metrics reset control reports unhittable in XCUITest;
its explicit coordinate taps prepare the sampler, wait for `ready`, then establish
`measuring` before stimulus. A final tap freezes the report after the interaction
and its animation tail; a watchdog result is invalid coverage.
Assert a journey’s return destination before using helpers that navigate elsewhere.

## Speed and synchronization

- Prefer deep links, seeded progress, and one launch per test. Use `relaunchApp`
  only for same-store persistence; it omits reset, seeding, starting resources,
  and onboarding bypass. Preserve real tab round-trips where tab wiring is the outcome.
- Readiness taps own existence, enablement, finite nonempty geometry, and
  hittability. A successful snapshot proves existence without a preceding query.
  Keep the final geometry/hittability recheck for animation races. Avoid an
  existence assertion immediately before tapping the same control.
  AudioLifecycle enables Music by dragging the muted thumb near the slider's
  leading inset. AX adjustment can leave Music at zero on iOS 26.2, so following
  it with a drag from the requested position can miss the actual thumb. The test
  checks the displayed change, real backend starts, and volume/playback persistence
  after relaunch; it does not seed volume or bypass the native control.
- `PlayScreen.startBattle` taps the stage action. Each caller waits for its actual
  next interaction: battle hand, card, Actions, or Auto-Battle. Do not add a generic
  battle-entry wait before that destination wait. Mid-battle tests still enter
  through Campaign with `allForMidBattle()` when setup timing matters.
- Use shared timeout defaults. Wait for alternative successful outcomes together;
  Contract return accepts earned talent choices or the board with a hittable Play tab.
- Scroll helpers resolve a container per reveal and return the final visibility
  result. Reuse that result. Filter inventory with `replaceText` instead of grid
  scroll loops; use stable IDs for primary actions.
  Prefer the target control's containing scroll view over a nested sibling carousel.
  Scroll gestures stay within the visible container above the floating tab bar;
  starting a drag over a tab can navigate away from the requested screen.
- Read numeric values and fallback labels from one snapshot. Homestead accounting
  reads each wallet/cost subtree once and waits for every resource balance.
  Coverage/audio and frame-metrics polls query their text probes directly, retaining
  the observed report; deferred-purchase setup retains the observed transaction.
- StoreKit registers the app once per runner; tests retain fresh sessions, transactions,
  and saves. Terminate the app before clearing transactions to avoid teardown revocations.
  Recovery asserts app access and usable purchase controls rather than polling StoreKit bookkeeping.
- Success screenshots require `TRINKET_UI_SUCCESS_SCREENSHOTS=1`; failures always
  retain a screenshot and bounded accessibility context through `record(_:)`, avoiding
  another full-tree snapshot when an existence assertion fails. Profile evidence remains explicit.
  Profile setup verifies native settings reached SwiftUI before gameplay assertions;
  audit sampling and full-matrix cadence follow [Player coverage](../Docs/Platform/PlayerCoverage.md#ci-and-profiles).
  Native Settings navigation scrolls the iPad detail pane
  independently of its sidebar, and unavailable prerequisites fail the requested
  cases without attempting dependent interactions. Original settings are restored.
- Completed xcresult exports are shared by filter validation, timing, diagnostics,
  and infrastructure retry only while bundle identity matches. Missing, damaged,
  or replaced evidence requires a fresh bounded export.
- UI runs remain serial on managed simulators. Specialized Performance, Profiles,
  and Soak source-only changes retain their manual/nightly/weekly cadence; shared
  support and unknown UI paths still trigger smoke. Local diagnostics follow
  [Verification](../Docs/Platform/Verification.md#local-simulator-budget).
  Inspect recorded hotspots with `python3 ./Scripts/test-timing.py report --top 30`.
- Hand-card queries target accessibility buttons rather than every descendant.
  Existence/disappearance assertions retain immediate checks and bounded native
  waits; readiness taps still validate geometry, enablement and hittability.
  Repeated Contracts reveal the first offer toward the top only when it is clipped,
  avoiding an unconditional swipe in every audio/soak cycle.
- Same-runner smoke and FullUI reuse local products. Transfers use the retained
  build artifact without a duplicate per-run archive cache. Requested FullUI continues
  after independent smoke failures when build products are usable; smoke still fails
  required CI. Simulator timing separates boot from bounded guest discovery;
  unavailable baselines forbid cleanup. Guest cleanup revalidates only its candidate
  and device parent before stopping it, retaining start-time and device ownership checks.

## Coverage ownership

- `SmokeBattleTests` owns Campaign entry, earned victory, committed claim,
  background return, Continue, and production-speed rapid cards/drag/retreat.
  The victory journey uses Auto-Battle; the input journey owns manual play and
  retreat once, replacing the separate slowed retreat launch. Duplicate settlement
  protection is package-owned by `PlaythroughLifecycleTests`. The termination
  journey uses the Chapter 1 victory fixture, taps the real claim, terminates at
  its stable committed-checkpoint identifier, then verifies the credited Gold,
  persisted progression, and next-stage entry after relaunch. Failed-write Leave
  proves recovery by starting another battle in the same process. Its former
  relaunch check only found the already-unlocked first stage; `DefeatCompletionTests`
  owns retry/settlement correctness.
- `BattleFlowUITests` shares one launch for inspection, dismissal, a held cancelled
  drag, and a committed drag after cancellation. `BattleCardGesturePolicyTests` owns
  numeric movement/play boundaries; the second sub-threshold flick is retired.
  Successful plays check the selected card's departure; draw effects can keep
  the total hand size unchanged.
  `DuoRotationUITests` runs only through Profiles in `player-coverage.sh duo`,
  retaining hand membership, reachable controls and post-rotation play. Keeping
  its intentional runtime skip outside FullUI permits CI's complete-execution
  proof before retrying classified launch failures. Actual folding remains an
  interactive Device Hub check.
- Localization retains every language and screenshot surface, but captures progression
  from Battle's shared `CombatantDetailPane` after dismissing ability inspection,
  before the same Campaign battle earns its talent choices. The seven language
  journeys share one launch with Options/purchase inspection using the localized
  native tab label. Double-length English retains a same-store relaunch directly
  into Options because its expanded native tab label belongs to the app process.
  All screenshot/hierarchy surfaces remain; StoreKit registration is once per runner.
  Collection and purchase journeys retain Collection entry wiring. The localized offer scrolls its
  content once and verifies Restore in the anchored footer beneath Purchase, following
  [Monetization](../Docs/Product/Monetization.md#offer).
- `SmokeShellTests` owns onboarding, retained starter access after relaunch, and
  the Collection → Homestead → Options → Play round-trip in the same career.
  Shell and onboarding changes route to that one owner. Recruitment opens the earned
  companion's detail in Collection and starts the next Campaign battle, proving
  usable access instead of matching a lock label.
  Full Game smoke owns character detail entry; equipment owns item detail/picker,
  equip, and actual unequip/reselect wiring. The equipment fixture keeps the target weapon
  visible. Reload/failed-write equipment semantics remain package-owned by
  `PresentationModelTests`.
- Merchant smoke pins one offer and compares board/detail prices, purchase, Gold
  debit, and return to Play. The fixed purchase footer signals detail readiness;
  avoid scrolling while artwork prepares. `ShopPurchaseApplierTests` and
  `AppStateShopEncounterTests` own item ownership and sold-stock rejection.
- Labyrinth boss/Continue retains battle and floor-selection interactions, checking
  the displayed floor after switching back to floor 1 and then floor 2. FullUI
  also covers Voyage embark/abandon, Spires locked-floor rejection and battle launch, and
  Labyrinth inspector selection/dismissal. Voyage stops at the returned offer board;
  `VoyagePersistenceTests` and `CloudSaveMergeVoyageClaimRegressionTests` own abandoned
  route encoding and disk reload, avoiding a duplicate cold launch and Explore traversal.
- Homestead accounting verifies displayed debit and tier in one launch;
  `PlayerHomesteadStoreTests` owns refused writes, exact debits and tiers across reload.
  Accessibility profiles stop after the tier change.
  Full Game smoke proves native Options rows accept taps. Options owns Reset cancellation
  with preserved progression and confirmed erasure across relaunch; cancellation alone
  no longer incurs a cold launch. The former Haptics thumb/relaunch
  case is retired: it protected a narrow preference binding at the cost of two
  launches. Dedicated Haptics UI persistence is no longer proved; real Music slider
  binding/playback persistence remains in `AudioLifecycleUITests`. One Contract
  plays a card after foreground return and checks its departure, music restart and
  subsequent SFX before Auto-Battle or board return can supply unrelated audio. The twenty-Contract soak
  owns repeated-battle audio coverage; `MusicPlayerRoutingTests` owns route rules.
- Full Game smoke seeds completed free chapters, opens Campaign from the Play
  hub, and taps the locked chapter's real offer entry. It purchases access to independently
  recruited Warlock, opens his detail, then plays the previously locked stage.
  Terminated Ask to Buy approval also owns
  populated cold-launch recovery: hidden purchase/restore actions, unchanged Gold
  and completed stages, recruited-character access, and a playable next stage.
  The separate direct-purchase cold-launch case is retired; both enter the same
  startup ownership reconciliation. Live approval, decline/retry, refund/repurchase,
  and restore-failure recovery stay separate.
  Cancellation never granting access is package-owned by `FullGameStoreTests`;
  declined Ask to Buy retries from the locked character. Active approval and
  restore-failure recovery observe app entitlement and purchase controls without
  repeating Collection navigation. Cold recovery and decline/retry retain character
  access wiring. Refund checks Gold and completed Campaign stages across relaunch,
  then repurchases through the revoked character's real purchase guard. Decline and
  refund prove denial through that guard instead of a lock-label suffix. Initial purchase allows
  StoreKit up to 60 seconds and requires offer dismissal and app entitlement before
  refunding. Live App Store restoration remains separate from local recovery.
- [Player coverage](../Docs/Platform/PlayerCoverage.md) owns settings profiles,
  twenty-Contract real-audio soak, interrupted settlement, and deferred live checks.
  Profiles require a played card to leave the hand and actually enter the stage unlocked by a claim.
  Each soak Contract compares audio with its own pre-battle baseline, excluding earlier tab visits.
  Audio observations prove backend scheduling/start results, not audibility.
  Accessibility audits exclude only the opt-in nonshipping diagnostics label, whose
  clipped one-point frame avoids covering controls at large text sizes. Each iOS audit
  type runs separately with one retry for a native timeout; violations and repeated
  timeouts fail with bounded element diagnostics.
- Reward and talent confirmation checkpoints hold presentation only in owned,
  cloud-disabled Debug stores. Background/disappearance uses ordinary finish paths;
  holds never authorize rewards or writes and are absent from Release.

## Performance measurements

Use `performance.sh --list` for scenarios/groups; the default is one pass.
`BattlePerformance.xctestplan` and the
[performance playbook](../Docs/Platform/PerformanceInvestigationPlaybook.md)
own explicit interaction windows, including victory and Mystery reveals.

Exit unselected tests before launch/probe setup. In multi-step equipment and talent
journeys, run only prerequisites for selected steps and skip trailing actions.
Talent reveal/choice preparation uses Debug Skip Combat before measurement; Campaign
smoke retains earned victory. Measurement windows and animation-tail budgets stay unchanged.
Combatant-detail scrolling starts after launch preparation and detail readiness;
there is no additional ten-second sleep. Existing animation-tail budgets remain.
Resolve sampler coordinates and gesture setup before capture. Snapshot scroll probes
outside `measured`, using one resolved surface for both snapshots and gestures;
failed movement retains the hierarchy and shared failure screenshot.
Prerequisite reveals reuse container-scoped scrolling above native tabs and pinned purchase actions.

Sampler controls explicitly establish `ready`, then `measuring`, and freeze the
report after the interaction and animation tail. A watchdog report is invalid.
Keep Battle's short polling cadence, card-count assertions, real audio, and existing
animation-tail budgets. State/report waits check immediately before bounded waiting.

Cold-launch metrics run with launch-animation selection, including the default matrix,
using production timing/audio without the Debug frame sampler. Launch-animation and
interaction scenarios keep instrumentation. Compare cold-launch results only when
launch arguments match. Production-timing journeys omit the tick override; audio
journeys omit audio suppression.
