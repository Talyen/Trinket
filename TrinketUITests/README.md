# TrinketUITests

UI test mechanics for Trinket. Agent workflow: `AGENTS.md`. Semantic test
ownership and keep/drop rules: [`Docs/Platform/Testing.md`](../Docs/Platform/Testing.md).
UI selector constants live in `Packages/TrinketFeatureSupport`. “Exhaustive” names
the existing suite, not a requirement to cover every mechanic or interaction;
use the canonical high-value threshold and retirement rules for selective player
journeys. Opening a surface or mutating state alone does not justify new UI coverage;
identify critical protection that package tests cannot provide. Account for launches,
waits, flakiness, and maintenance; medium-value additions are rare, justified exceptions.

## Layout

| Area | Path | When |
|------|------|------|
| Smoke | `Smoke/` sources; `Smoke.xctestplan` at repo root | CI `test.sh smoke` (registry-defined classes); runs on the build runner without a product transfer |
| Exhaustive | `Play/`, `Collection/`, `Battle/` | Advisory nightly/dispatch CI, runs all registered classes on one runner; includes StoreKit recovery; deliberate local diagnostics follow [Verification.md](../Docs/Platform/Verification.md#local-simulator-budget) |
| Performance | `Performance/`, `BattlePerformance.xctestplan` (repo root) | Manual CI `performance.yml` / `performance.sh` investigations; outside routine smoke |
| Profiles | `Profiles/`; generated `Profiles.xctestplan` | Nightly/manual compact iOS 26 phone and portrait iOS 27 iPad; three settings configurations per device |
| Soak | `Soak/`; generated `Soak.xctestplan` | Weekly/manual audio-enabled twenty-Contract career; outside routine FullUI |
| Support | `Support/` | Shared launch and StoreKit fixtures; page objects (`PlayScreen`, `BattleScreen`, `TabBar`, …) |

Author smoke and exhaustive membership once in `Scripts/config/ui-tests.tsv`.
Each row supplies suite, smoke routing key (empty for other suites), and class.
Selections follow registry row order. `./Scripts/generate.sh` updates only
`selectedTests` in the UI plans, preserving other plan settings. Profiles and Soak plans are generated from the FullUI plan settings when first created. CI reads all FullUI classes through `check-testplan-sync.py --classes FullUI` and serial
smoke filters through `--classes Smoke`; local smoke routing uses the same rows. Add, remove, or move registrations with the source
class, then regenerate. The checker rejects missing/duplicate classes, duplicate
routing keys, stale plan selections, and workflows bypassing registry selections.
Focused runs require every requested filter and at least one executed test in the
result tree. When export stalls, terminal per-test log records provide that proof;
a suite summary alone does not. Documented individual skips remain visible in results. CI requires a runtime that
executes the Full Game purchase journey; the documented iOS 26.5 purchase skip
is local-only.

The merchant smoke journey owns the purchase button, displayed gold debit, and
return to Play. Purchased-item ownership and sold-stock rejection are proved by
`ShopPurchaseApplierTests` and `AppStateShopEncounterTests`; smoke avoids a second
purchase attempt and a Collection traversal. The equipment UI journey owns picker,
equip, and unequip-control wiring. `PresentationModelTests` proves equipment survives
reload, including failed-write rollback and retry, so the UI journey avoids another
cold app launch. The Debug-only equipment fixture retains equipped items and the target weapon,
so the selected weapon is visible without keyboard search or a broad scroll budget. The Labyrinth boss/Continue journey retains
its battle and floor-selection interactions because they protect distinct UI wiring.

## Launch args

Defined as `TestLaunchArg` in `Support/TrinketUITestCase.swift` and parsed by
`AppEnvironment`. Helpers include `allForScreen`, `allForTab`, `allForBattle`,
`allForMidBattle`, `allForShop`, and
`completedStages`. Use the source type for the complete, current catalog.

**Default smoke args:** `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`.

`launchApp` waits for the launch artwork cover to finish before returning, so
screen-readiness assertions measure their destination rather than cold artwork
preparation. Its bounded timeout lives in `TrinketUITestCase`; a warmup timeout
fails explicitly instead of being reported as a missing destination.

Common screen-entry arguments are `-launch-screen` and `-selectedTab`; state
seeding uses `-completed-stages`, `-starting-gold`, and the reset/cloud-sync
flags. Performance-only frame metrics are opt-in and never belong to smoke.

Keep default launch args unless testing persistence. Prefer `AccessibilityID`
selectors and assert with `assertExists`; use visible text only when it is the
product contract. UI tests tap tab labels, not `AppTab` raw values. Sheet dismissal names the expected
sheet identifier and waits for it to disappear. Native sheet drag dismissal is
used where the screen intentionally has no Close control; Back selects the native
`BackButton` identifier rather than an arbitrary navigation-bar button.

Normal control taps use the shared default timeout and require existence,
enablement, a finite nonempty frame, and hittability. Check geometry before
hittability because sheet transitions can temporarily expose invalid frames.
Use explicit
coordinate gestures only for gesture tests or a demonstrated automation limitation.
The transparent frame-metrics reset control reports unhittable in XCUITest;
its explicit coordinate taps prepare the sampler, wait for `ready`, then establish
`measuring` before stimulus. A final tap freezes the report after the interaction
and its animation tail; a watchdog result is invalid coverage.
Assert a journey’s return destination before using helpers that navigate elsewhere.

## Speed

- Prefer `-launch-screen` / `-selectedTab` deep links; do not re-navigate a screen launch args already opened.
- Prefer one launch per test with explicit per-test args. For persistence, use
  `relaunchApp(arguments:)`: it reuses the test store and takes destination arguments
  without reset, seeding, starting resources, or onboarding bypass.
- StoreKit's registration-only launch skips the artwork wait; its subsequent
  test launch still waits for preparation before interacting with controls.
- Prefer one launch + `TabBar` for round-trips that must exercise the tab bar itself.
- Prefer `-completed-stages` over scrolling Stage Select lists when seeding progress.
- Filter inventory/search with `replaceText` instead of grid scroll loops.
- Prefer `AccessibilityID` selectors over visible labels for primary CTAs (Aspect Begin Floor, Labyrinth node actions).
- Mid-battle exhaustive tests enter through the Play map with
  `TestLaunchArg.allForMidBattle()`; do not deep-link into a live battle when
  setup timing matters.
- Campaign entry, manual card play, earned victory, and Continue navigation belong
  to [SmokeBattleTests](Smoke/SmokeBattleTests.swift).
  Performance measurements use `BattlePerformance.xctestplan` under the
  [performance playbook](../Docs/Platform/PerformanceInvestigationPlaybook.md);
  that plan measures explicit interaction windows, including victory and Mystery reveals.
  `performance.sh --list` lists scenarios and groups; its default is one pass.
- In performance journeys, capture and verify scroll probes outside `measured`.
  Establish a newly opened scroll surface before capturing its probes; measure
  its gestures separately when the scroll itself needs a frame report.
- Required Full Game coverage includes purchase access to an already-recruited premium character
  and a chapter offer-entry check. Existing-entitlement cold launch and recovery from simulated restore
  failure are advisory FullUI journeys. Tapping Restore while already unlocked does
  not prove restoration; real App Store restore still needs service/device evidence.
- Use the timeout and tick defaults from `TrinketUITestCase` and its helpers;
  do not copy their numeric values into this guide.
- Wait for alternative successful outcomes together. Battle entry accepts the
  hand or victory in one wait, so a fast victory does not exhaust a hand-only wait.
- PD-014 permits the bounded critical-control settings profiles described in [Player coverage](../Docs/Platform/PlayerCoverage.md). Use stable selectors and meaningful outcomes; [Testing.md](../Docs/Platform/Testing.md#ui-keep-drop-rubric) owns when copy, layout, or gesture behavior merits regression coverage.
- UI tests are CI-owned and run serially on each job's managed simulator. Local diagnostics require explicit opt-in under Verification.md. Hotspots: `python3 ./Scripts/test-timing.py report --top 30`.
- Success-path screenshots are opt-in (`TRINKET_UI_SUCCESS_SCREENSHOTS=1`); failure screenshots stay unconditional.

## Coverage consolidation

The hand-card inspection, dismissal, cancelled-drag, and committed-drag checks share
one battle launch in `BattleFlowUITests`. Each gesture retains its hand-count and
detail-sheet assertions; the test ends after the committed play.

Onboarding and recruitment finish by checking that the earned characters are
present and unlocked in Collection. Shopping verifies the purchase control,
Gold debit, and return to Play; item ownership remains package-owned as described
above. Repeated detail-sheet openings are removed. Collection
character-detail entry remains covered by `FullGamePurchaseSmokeTests`, and item
detail entry by `CollectionLoadoutUITests`. Character lock labels express the
unlock contract because locked character cards remain enabled for inspection.

Full Game's smoke purchase journey owns Warlock detail entry.
Existing-entitlement cold launch and restore-failure recovery stop at the accessible
Collection card instead of repeating detail navigation. These fixtures seed recruitment
independently of StoreKit ownership. The shared assertion checks the card's lock
label, which combines recruitment and purchase access. Purchase preserves the earned
recruitment and progression rules in [Monetization](../Docs/Product/Monetization.md#access).

## Real-player coverage

[Player coverage](../Docs/Platform/PlayerCoverage.md) owns the expanded portfolio,
CI cadence, evidence boundaries, and deferred live checks. FullUI now restores
Voyage embark/abandon, Spires locked-floor/detail wiring, Labyrinth inspector
selection/dismissal, Homestead upgrade/debit/reload, Haptics toggle/reload,
Ask to Buy, and failed-write Defeat Leave. Haptics is the explicitly approved
narrow medium-value exception; it proves the native control binding that the
Options defaults tests cannot establish.

The Campaign smoke journey holds at the opt-in Debug reward checkpoint after the
real claim commits, then backgrounds and returns to the map. Collection and
Talent confirmation checkpoints never authorize rewards or writes: backgrounding
and disappearance execute the ordinary finish paths. Only owned, cloud-disabled
Debug stores may hold presentation completion. Release builds contain no holds.

Production-timing journeys omit the tick override; audio journeys omit audio
suppression. `Coverage Diagnostics` is an opt-in Debug label; the native audit
excludes only this nonshipping observation element. All product controls remain
audited. Captured backend counts establish scheduling/start results, not audibility.
