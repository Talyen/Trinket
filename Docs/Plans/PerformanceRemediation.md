---
type: execution-plan
status: active
created: 2026-09-14
updated: 2026-09-14
expires: 2026-09-28
---

# Performance remediation

## Objective and execution contract

Reduce player-visible stalls during browsing, scrolling, navigation, and combat
without reducing presentation quality or changing game/save behavior. Use this
plan as the execution queue for a subsequent agent. This document records measured
symptoms and recommended investigations; it does **not** establish their causes or
authorize speculative rewrites. No application remediation was performed while
writing it.

Read [AGENTS.md](../../AGENTS.md), the
[performance playbook](../Platform/PerformanceInvestigationPlaybook.md), and
[verification policy](../Platform/Verification.md). Route the actual files before
each workstream, inspect overlapping dirty diffs, and preserve other work. Work
in the primary checkout by default; do not commit, push, or submit a release unless
requested. Load the simulator skill before Simulator operations, the design skill
for visual/interaction changes, and the architect skill for public package contracts.

The active [ArtworkPreparationHitches plan](ArtworkPreparationHitches.md) overlaps
launch, artwork acquisition, and equipment search/navigation. Read its current
status and inspect current code before changing those areas. Its prior experiments
are history, not instructions to reintroduce abandoned approaches. Coordinate any
unclear overlapping edits with their owner; do not overwrite them. Do not execute
unrelated plans as part of this work.

## Evidence and interpretation

The source run is `.DerivedData/PerformanceResults/coverage-verified-20260914/`:

- `reports.json`: complete numeric reports, per-step launch arguments, and source log references.
- `baseline.json`: the exact selected inventory, thresholds, and XCTest method mapping.
- `environment.json`: revision, dirty state, tracked diff hash, and hashes of new source files.
- `summary.md`: all observations against the configured goals.
- `TestResults/`: finalized xcresult, invocation manifest, and raw XCTest logs.
- `Screenshots/manifest.json`: exported Campaign, combatant detail, and Mystery reward images.

Run facts: September 14, 2026; Xcode 27.0 build 27A266a; macOS 27.0 arm64;
iPhone 17 Pro Simulator, iOS 27.0 (`iPhone18,1`); Debug with Swift `-O`;
60 Hz target; one measured repetition; quick preparation disabled. Base revision
was `12856cdf87181a75e7017c6af0e7a2f85482fc7e` **with uncommitted changes**.
The revision alone cannot reconstruct this build. Source fingerprints were checked
unchanged throughout capture. The matrix finished in approximately 24 minutes:
48 tests passed, zero failed/skipped, and all 91 required step reports were valid.
The tooling handoff subsequently passed 230 package tests and repository gates.

**90 of 91 scenarios exceeded at least one observation goal.** The sole clear
scenario was `hand-drag-cancel`: 16.7 ms maximum interval, 60.1 average FPS,
60.0 FPS at the 1% low, and zero missed deadlines/severe stalls. This breadth of
findings requires investigation of common costs and measurement effects; it does
not prove 90 independent app defects. The injected 120 ms diagnostic stall was
successfully detected in a separate run and is excluded from this matrix.

The sampler measures delivered display-link callbacks, not presented frames or
render-server/GPU hitches. XCTest snapshots, keyboard interaction, system work,
and Simulator scheduling can influence it. Several scenarios combine actions:
`equipment-search-filter` includes the rarity menu, keyboard appearance, typing,
result updates, and keyboard submission/dismissal. Its worst interval cannot yet
be attributed specifically to filtering. No causative Time Profiler or device
Animation Hitches trace accompanied these findings. Device Hub displayed images
but ignored Computer Use input; screenshots plus XCTest movement assertions were
used, and do not establish perceptual smoothness. Physical-device rendering,
ProMotion, thermal/long-session behavior, and live service variability remain
unverified and outside the initial Simulator remediation scope.

The complete numeric inventory is copied below so this plan survives local artifact
cleanup. If artifacts are unavailable, run a fresh baseline; do not reconstruct a
trace or claim an exact old build from the revision alone. Do not use the older
`coverage-final-20260914` session as complete evidence: its 20-minute suite limit
interrupted execution. That runner limit has already been corrected independently
of the unchanged 60-second per-interaction watchdog.

## Priority queue and conditional fixes

Priorities below order investigation, not confirmed defect severity. Keep one
workstream active at a time and carry proven shared fixes into later workstreams.
Numbers are from the single source run and are rounded.

### 0. Establish trustworthy attribution before optimizing

- [x] Inspect the recorder/probe, `PerformanceJourneyUITestCase`, scenario bodies,
  and the source run's exact fixtures. Keep the diagnostic stall check available.
  Begin with `equipment-search-filter`, `starter-companion-confirm`, and
  `hand-drag-cancel` as two high-signal cases and a control.
- [x] Run each selected case once on the current optimized build. Use one additional
  run only when a result is inconsistent or the change needs confirmation. Keep
  all reports; a clean rerun never replaces an earlier bad one.
- [x] Capture a short trace starting before the offending action and ending after
  its visible tail. Separate untraced benchmark comparison from traced diagnosis:
  tracing itself changes overhead. For compound steps, narrow the reproduction to
  each constituent action. Add a temporary narrow signpost only if existing traces
  cannot distinguish plausible owners; remove temporary diagnostic code afterward.
  (`xctrace` host-attach proven unusable on this host; used tap-aligned `sample`
  instead with the same before/after discipline. Temporary test-side markers used
  for alignment were all removed. Traced runs are diagnosis-only: consistently
  worse than untracked, never compared as benchmarks.)
- [x] Check whether stalls align with app stacks, accessibility snapshot handling,
  keyboard/system work, or host contention. Compare an equivalent interaction
  without repeated AX queries when tooling permits. Preserve real gestures and
  completion assertions; do not shorten the measurement window to exclude a stall.
  (Aligned: AX snapshots in scroll windows; SurfacePool waits in starter windows;
  clean CPU in typing/engine windows. Live-probe comparison attempted, proven
  worse, reverted — snapshots retained as the only atomic check.)
- [x] If instrumentation is the cause, fix its owning probe/test helper, retain the
  stall detection and completeness checks, and recapture affected baselines. If
  evidence only points to system/Simulator scheduling, record that classification
  and defer device confirmation instead of inventing an app fix. If CPU evidence
  is clean but motion still appears impaired, classify it as render/device evidence
  pending. Never relabel an unresolved observation as fixed.
  (Helper migrated at 15 sites with detection intact and baselines recaptured;
  system/render rows classified with evidence. No unresolved row relabeled.)

### 1. Equipment search, filtering, and navigation

Evidence: search/filter **946.4 ms max / 47.0 avg FPS / 23 severe stalls**;
picker scrolling **341.7 ms / 56.2 FPS**; inspect/equip **186.1 ms / 50.1 FPS**;
unequip **102.4 ms / 52.8 FPS**.

Owners: `ItemSlotPickerView.swift` and `ItemPickerItems.swift` under
`Packages/TrinketFeatureSupport/Sources/TrinketFeatureAdapters/Shared/Detail/`,
plus the current detail navigation/artwork lease helpers. The search model already
caches normalized text and keeps visit ordering: inspect invalidation and refresh
frequency before proposing another cache or rewriting search.

- [ ] Trace rarity selection, keyboard opening, typing `long`, filter publication,
  and submission separately. Check repeated inventory normalization/sorting,
  observation-driven model rebuilds, native search dismissal/navigation, and
  artwork admission versus actual decode/render cost.
- [ ] If model work dominates, reuse existing derived data until its actual inventory
  dependencies change and avoid repeated sorting/publication. If artwork dominates,
  fix the established preparation/lease/viewport owner. If native search lifecycle
  dominates, preserve the current acknowledged dismissal and navigation ordering;
  do not replace it with arbitrary sleeps. Add asynchronous work/cancellation only
  when the traced cost justifies it, with stale-result protection.
- [ ] Verify rarity/keyword filters, empty results, clearing, preserved query and
  order after Back, equip/unequip dismissal, and failed-save retry. Keep filtering
  responsive; no unrequested debounce delay or omitted intermediate updates.
- [ ] Compare all four equipment scenarios and run the existing equipment functional
  journey when its wiring changes. Reuse or strengthen semantic tests for any
  changed invalidation/filtering behavior rather than duplicating UI assertions.

### 2. Starter completion and launch

Evidence: Companion confirmation **421.6 ms max / 19.7 avg FPS / 47 severe stalls
in 7.5 seconds**, versus Hero confirmation **95.4 ms / 59.1 FPS**. Launch animation
had **359.7 ms / 48.7 FPS**. The sustained Companion result makes this a distinct
priority even though its maximum is below equipment search.

Owners: `Trinket/Features/Onboarding/StarterSelectionFlow.swift`, starter selection
persistence/orchestration, and `Trinket/App/TrinketApp.swift`, `HiddenTabPrewarm.swift`,
`LaunchWarmupView.swift`, and `LaunchArtworkCensus.swift`.

- [ ] Trace Companion confirmation through save completion, Play/shell construction,
  hidden-tab layout, resource/cast preparation, and first interactive frame. Compare
  Hero confirmation to identify the extra work that completing onboarding adds.
- [ ] If duplicated construction or broad observation dominates, retain the existing
  owners and eliminate repeated work/publication. If synchronous resource work
  dominates, use the established off-main preparation/admission path before
  publication. Fix causative ownership/lifetime errors, not only a visible symptom.
- [ ] Preserve the intentional launch-cover hold, readiness acknowledgements, and
  latched completion. Do not reduce the hold, substitute fake progress, skip hidden
  prewarm, expose unprepared art, or move necessary work onto the first scroll/tap.
- [ ] Verify fresh Hero/Companion choice, transition to Play, subsequent launch,
  reset-to-onboarding, and a slow-preparation route. Compare `launch-animation`,
  `starter-hero-confirm`, `starter-companion-confirm`, and `options-reset-confirm`.

### 3. Shared navigation, artwork, and scrolling

Evidence: Collection detail **345.0 ms**, Companion detail **339.9 ms**, tab round
trip **221.3 ms**, Battle inspection **202.7 ms**, Campaign entry **184.8 ms**,
enemy detail **184.4 ms**, and Homestead detail **181.9 ms**. Scroll-only examples
also show misses: talent tree **131.6 ms**, combatant detail **63.0 ms**, and
Labyrinth **57.3 ms**. Compound navigation-and-scroll cases must be separated in
traces before assigning their maxima to scrolling.

Owners: existing prepared sheet/navigation helpers, `DetailHeroScrollShell`,
`PreparedArtworkCache`, `ArtworkViewportPrewarm`, Collection grids, and each
feature's presentation owner. Preserve the existing admission scheduler and leases.

- [ ] Determine whether the shared cost is image decode/upload, repeated detail
  construction, header/layout invalidation, effects preparation, or unrelated AX
  work. Use one first-entry and one return/scroll reproduction; avoid a new generic
  presentation abstraction merely because several reports are slow.
- [ ] If resource preparation is responsible, correct missing acquisition/pinning,
  duplicate preparation, or lifetime errors at the shared owner. If invalidation
  is responsible, narrow observation or reuse immutable derived geometry/content
  where supported by the trace. Keep scroll-driven prefetch effective.
- [ ] Validate entering, scrolling, dismissing, and re-entering details, plus asset
  visibility on new rows. Rerun a representative consumer in Collection, Campaign,
  Battle, and Homestead for a shared fix, then all affected category variants once.
  Do not claim short content that fits the viewport proves an overflow scroll.

### 4. Save-backed actions, rewards, and returns

Evidence: reset **250.1 ms**, defeat save recovery **207.2 ms**, salvage **201.5 ms**,
talent unlock **192.2 ms**, corruption reveal **184.3 ms**, chapter progression
**164.8 ms**, floor progression **161.7 ms**, retreat **159.0 ms**, talent reveal
**157.9 ms**, victory claim **149.1 ms**, and Shop purchase **147.3 ms**.

Owners: `PlayerSaveStore`, the current Play/encounter completion owners, shared
reward presentation, and the relevant feature's action state. Read persistence and
battle completion contracts before changing these paths.

- [ ] Correlate `PlayerSaveMutation` / `ModelContextSave` and existing transition
  signposts with the stall. Determine whether cost is persistence, duplicate
  projection/observation publication, reveal construction, or dismissal/layout.
- [ ] Remove only trace-proven duplicate work or overly broad observation. Move
  pure expensive computations off-main where safe; do not move SwiftData objects
  across actors, weaken atomic saves, defer durable claims past success feedback,
  skip retries, or couple reward amounts to animation completion.
- [ ] Verify exactly-once claims, failed-save retry, equip/salvage state, reset
  boundaries, and correct Campaign/Labyrinth/Collection return destinations with
  the existing semantic tests appropriate to the changed owner. Keep full reward
  reveals, deposit/dissolve effects, audio, and haptics.

### 5. Combat and the residual inventory

Evidence: `real-card-play` **41.6 ms max, 3 missed deadlines** exceeds its stricter
20 ms/zero-miss goals. `engine-hand` **40.2 ms**, `engine-feedback` **50.0 ms**, and
`combined-worst-case` **42.3 ms** are leads, not proof of engine or feedback CPU cost.
The clean drag-cancel result must remain protected.

- [ ] Follow the playbook's engine/projection → feedback → gesture sequence. Only
  optimize the stage with an attributed expensive stack. Preserve immediate card
  removal/reflow, real drag/cancel, audio/haptics, effects timing, and feedback richness.
- [ ] After shared fixes, run the full matrix once and re-rank the remaining rows
  from the appendix. Investigate the largest remaining app-attributed stalls first;
  classify all remaining observations rather than applying speculative fixes to
  every one of the original 90 flagged scenarios.

## Reproduction and verification workflow

From the repository root, select exact scenarios with repeated selectors:

```sh
./Scripts/performance.sh --scenario equipment-search-filter
./Scripts/performance.sh --scenario starter-companion-confirm --scenario launch-animation
./Scripts/performance.sh --group collection
./Scripts/performance.sh --group battle
./Scripts/performance.sh --group diagnostic
```

Use the inventory's current `--list` output when names change. Default to one pass;
use `TRINKET_PERFORMANCE_REPETITIONS=2` only to resolve uncertainty. Keep quick mode
off for comparison evidence. Fixtures and functional assertions must remain intact.
The diagnostic group intentionally injects a stall and is not a performance target.

For CPU attribution, use the managed simulator workflow and the playbook's
host-attachment route:

```sh
./Scripts/record-time-profiler.sh --attach <verified-Trinket-PID> --time-limit 8s --output <fresh-path.trace>
```

Replace placeholders with the PID belonging to the current leased app and a fresh
output path. Arrange the trigger so recording begins first. The normal performance
runner relaunches per test: do not attach once by process name and assume a trace
covers subsequent launches. Use an equivalent scoped reproduction under a held
lease, or bounded test/trace coordination; do not kill another agent's process.
Do not use `xctrace --device <simulator>` or host `--all-processes` as a shortcut.
Load the device skill if a later explicit device-validation task is undertaken.

After each supported fix, run its meaningful unit/functional checks and the
selected performance case once. Use the same source configuration, fixture,
runtime, target, and untraced measurement method for before/after comparisons.
Record per-step duration as well as FPS/miss/stall values; differently scoped
windows are not comparable. If a scenario must be split, give new steps explicit
identities and establish a fresh baseline while retaining the old evidence.
Run the entire Battle matrix only for shared Battle-boundary changes. Run the full
app matrix once after the complete remediation pass, rather than after every edit.

Do not lower thresholds, suppress scenarios, average away a bad repetition, trim
an animation tail, disable production work, or promote the baseline to `enforce`
to make this plan look complete. The [playbook](../Platform/PerformanceInvestigationPlaybook.md)
owns current budgets and performance goals. Test reliability fixes require proof
that the intended interaction still occurs and that the injected stall is detected.

## Completion criteria and execution ledger

For each priority/workstream, fill in the table while working. A successful fix
requires an attributed cause, the smallest coherent change, valid before/after
reports showing improvement in the relevant tail/stall metrics, and no regression
in shared consumers or functional behavior. Meeting the baseline remains the
long-term target; a partial improvement with remaining findings is not closure.
Classify unresolved system/render cases explicitly and leave follow-up work open
when required evidence is unavailable. An isolated clean rerun is not sufficient
proof that the original issue disappeared.

| Workstream | Reproduction / trace | Confirmed owner and cause | Change | Before/after artifacts | Functional checks | Status / next action |
|---|---|---|---|---|---|---|
| Attribution/control | Reran `hand-drag-cancel`, `equipment-search-filter`, `starter-companion-confirm` once each on current tree (`.DerivedData/PerformanceResults/20260914T222657Z/`). Control regressed from clean (16.7 ms/0 miss) to 33.3 ms/1 miss/45.0 1% low without code change; high-signal cases reproduced (search 840 ms/17 severe, companion 382 ms/44 severe). CPU attribution obtained via `sample` (`.DerivedData/PerformanceResults/traces/sample-equip{1,2}-20260914T161426Z.txt`, same app PID 36357, Debug `-O`, Agent 1 lease): `xctrace` host-attach is unusable on this host — PID-attach reports "Cannot find process" for `launchd_sim` children (verified against live PID 15629) and name-attach collided with a stale detached PID 22767 (since exited on its own; never killed). Sample 1 (launch + picker-scroll + search start, 25 s): app-main-thread AX snapshot tree ~1,000 samples (`_accessibilityUserTestingSnapshotWithOptions` → descendants walk → per-symbol string-table file I/O), zero persistence frames (1 `sqlite3` hit file-wide), SFX catalog warmup off-main (utility QoS, ~1.7 s CPU, host contention only). Sample 2 (typing/submission tail, 20 s): main thread ~85% idle, app code ~zero, AX minimal — yet the traced run still showed a 532 ms max / 34 severe (worst of all runs; `sample` at 1 kHz perturbs delivery, so traced numbers are diagnosis-only, never benchmarks). Harness migration (approved for clarity, not game improvement): `exerciseScroll` split into `captureScrollProbes` / `performScrollGestures` / `verifyScrollProbes`; snapshots now run outside the measurement window at 15 sites across 8 files (5 left unchanged where content is dismissed mid-block: companion-detail, collection-category, campaign-party-picker, spire-climb, battle-inspection, battle-log). All 15 migrated scenarios produce valid reports with movement assertions passing (`20260914T233058Z`: 5 collection scenarios; `20260914T233400Z`: 10 more). Tails show no improvement beyond variability (several maxes flat-to-worse, consistent with session host-load variance; no thermal event recorded) — expected: the game is byte-identical. Value is strictly future attribution clarity; old baselines retained above alongside new reports. A live-probe alternative (single-element frames) was tried first, proven worse (stale-element abort, 35 s window, 479 misses), and reverted with green confirmation (`20260914T232123Z`). | Instrumentation (AX snapshots) trace-proven as material main-thread cost inside scroll windows, but snapshots are the only atomic movement check — retained, cost documented. Search-filter tail has clean main-thread CPU ⇒ render/system/Simulator per plan, pending device confirmation. No Time Profiler/signpost trace (tooling limitation above). | None kept (snapshot helper reverted to original; `ItemPickerItems` hygiene lives in Equipment row) | Source run, `20260914T222657Z`, `20260914T231426Z` (traced), `20260914T231830Z` (broken probe experiment, invalid picker-scroll evidence — retained as negative evidence), `20260914T232123Z` (revert check) | Detector intact; movement assertions still passing (failed loudly when broken, confirming they work) | Partial; next: device Animation Hitches + Time Profiler for the search-filter max; scroll-scenario maxima carry known snapshot overhead |
| Equipment | Reran all four equipment scenarios post-fix (`.DerivedData/PerformanceResults/20260914T223333Z/`): picker-scroll 389.5 ms/4 severe, search-filter 656.2 ms/18 severe, inspect-equip 209.4 ms/9 severe, unequip 105.6 ms/6 severe. Later identical-code reruns: 841.8, 642.4, 372.5, 423.7, 532.0 ms max — spread proves run-to-run variability dominates; no improvement claimed. Push-window analysis (sample-equip1): ~one ~117–200-sample `NavigationStackCoordinator.updateNavigationController` → `prepareNavigationBar` → toolbar-preference chain = ONE-TIME construction of the pushed picker's nav/toolbar, not repeated work; `ItemPickerItems.update` 1 sample, `matching` 2, bodies single digits — model FULLY exonerated in all windows. Artwork is pre-leased before the push by construction (parent task awaits lease before setting destination). | Typing-window max unattributed to app CPU (clean). Push cost is necessary one-time framework construction — nothing redundant found, nothing eliminable without changing the toolbar UI (product surface, needs approval). | `ItemPickerItems.update` early-return + new-items-only sort (hygiene, kept, tested) | Source run, `20260914T222657Z`, `20260914T223333Z`, sample-equip{1,2} | `TrinketFeatureSupport` 94/94; `HeroDetailAbilityPickerUITests` smoke 2/2 | Model closed (exonerated); push closed (necessary construction). Remaining max = render/system + AX snapshots (see Attribution row) |
| Starter/launch | Tap-aligned `sample` traces (`.DerivedData/PerformanceResults/traces/sample-starter{,2,3}-*.txt`; temporary test-side marker used for alignment, removed afterward). Key finding: main thread parks in `RB::SurfacePool::wait_image_queue` (usleep/semwait) — 5,212/3,821/4,946 samples across three traces, including one that missed the transition window entirely (ambient on onboarding screens). With an 8.05 s window reporting 411.8 ms max / 48 severe, the main thread was ~72% in render-surface waits, not app CPU. Save at tap is ~85 samples via `resetRootDurably`-style durable path with ~zero SQLite — necessary, not the owner. Untraced runs (382–850 ms max) corroborate real parks. | Tail dominated by render-pipeline backpressure under Simulator software rendering (commits outpacing drain: crossfade + plasma backgrounds + shine timelines + 3 hidden tabs + Play mounting together), NOT app CPU. Nothing eliminable without reducing committed animated surface = visual tradeoff (out of bounds). Sequencing the hidden-tab prewarm was designed and then DECLINED: ambient waits in a transition-free sample prove steady-state over-commit, so sequencing would redistribute rather than remove waits, while touching latched launch machinery shared with the active ArtworkPreparationHitches plan. An idle-composition check (30 display-link ticks, 1 layout, 3 Timeline frames vs 3,821 waits) shows no view-side driver `sample` can attribute; surface-lifecycle attribution needs the device-only Animation Hitches template (waived), so no further Simulator-side diagnosis is available for this family. | None (eliminate-only rule + no-visual-reduction constraint; staggering prewarm or deferring work would move the stutter, not eliminate it) | Source run, `20260914T222657Z`, `20260914T234151Z` (411.8/48), `20260914T234045Z` (445.6/49) | Pending full pass | Classified render/system. PROPOSAL for product (no code change): reduce concurrent full-screen animated layers on starter/play-entry screens if the stutter matters on device; device Animation Hitches required before any hitch claim |
| Shared navigation/scroll | Tap-aligned `sample` batch (`sample-nav-{tabtrip,collection,enemy}-*.txt`, temporary markers, removed; traced run reproduced maxima: 355/203/412 ms). All three windows: ZERO `NavigationStackCoordinator.update`, trivial TabView/detail-construction frames (≤10), zero saves, zero SurfacePool waits. Dominant in-app cost is serving test queries/snapshots (760–955 snapshot + 770–855 matching frames ≈ 10–20% of main samples); transitions themselves (push, sheet-dismiss drag + spring, 4 tab switches) register ~zero app CPU. | Navigation transitions EXONERATED as CPU owners — no redundant construction, no repeated layout, artwork pre-leased/async by existing design. Maxima live in transition animations (render), first-layout texture upload (GPU), individual query blocks, and system gaps. No code change available without touching visuals or weakening terminal assertions. | None (visuals untouched; terminal assertions retained) | Source run, `20260915T000833Z` (355/203/412) | Pending full pass | Closed for transition CPU (evidence-backed). Same signature presumed for homestead-detail, campaign-entry, battle-inspection siblings; spot-check on request. Artwork-lease ownership untouched per overlapping plan |
| Saves/rewards/returns | Tap-aligned `sample` of `options-reset-confirm` (`.DerivedData/PerformanceResults/traces/sample-reset-*.txt`, temporary marker, removed). Reset = ONE durable `resetRootDurably` → `savePrimaryGraph` (~146 main-thread samples incl. one-time Swift-conformance + CoreData performAndWait; sqlite ≈ 10). An apparent "double save" in aggregate counts was verified by reading `PlayerSaveStore+Reset.swift` to be a single call (two hot PCs, not two writes) — no fix made, correctly. Transition/alert/AX make up the rest of the 313.8 ms max / 6 severe. Outcome batch (tap-aligned `sample-outcome-*`, markers removed): `defeat-save-recovery` shows 568 AX samples + 174 `NavigationStackCoordinator.update` with ZERO save/completion frames — the 830 ms traced max is transition + test queries, not the recovery write. `postbattle-talent-reveal` (512 AX, rest ~0) and `victory-claim-return` (358 AX, rest ~0) likewise. Setup scrolls hoisted before measurement per prerequisite precedent (victory-claim, talent-reveal, chapter-progression; talent-choice's mid-flow reveal verified unhoistable and left in place). Post-hoist rerun (`20260914T235718Z`): victory 172.8/3, defeat 195.2/4, talent 195.3/3, chapter 241.0/2 vs source 149/3, 207/4, 158/2, 165/1 — flat within variability, no improvement claimed. Second batch (`sample-batch2-*`): `talent-unlock` = single `unlockTalent` → `persistBatch` (~100–172 samples, one atomic roster mutation, must stay) + AX; `salvage-return` = single `salvageItem` → `persistBatch` (~239–397, one durable inventory/roster/materials write verified single-call in `ItemSalvage.swift`, must stay) + heavy alert/assert AX; `battle-inspection` = AX-dominated (856 + 1,362) with in-window scroll snapshots unmovable (surface dismissed after) + trivial detail frames. Traced maxima (285/556/648 ms) all exceed untraced runs — tracer perturbation confirmed again. `shop-scroll` failed once post-migration ("did not expose moving content") then passed twice (45.2, 56.0 ms): offer-dependent fixture flake, not systematic — evidence pass/pass/fail/pass. | Single necessary atomic durable saves + one-time runtime costs; nothing duplicated, nothing eliminable (weakening/deferring saves is forbidden). | None (eliminate-only rule) | Source run, `20260914T234346Z` (313.8/6), `20260914T235405Z` (traced), `20260914T235718Z` (post-hoist) | Pending full pass | Reset + outcome batch closed (evidence-backed); remaining save siblings (defeat-retry, reveals, talent-choice, salvage, shop-purchase) open with this template |
| Battle/residual rows | Tap-aligned `sample` of `engine-hand` (`.DerivedData/PerformanceResults/traces/sample-engine-*.txt`, temporary marker, removed). Main thread 92% idle across the window with ZERO `Battle*`/projection/publication frames — engine resolution completes in milliseconds, before/without registering. The traced run still reported 97.8 ms max / 3 severe against that idle main thread: pure system/Simulator gaps + tracer perturbation. Control `hand-drag-cancel` previously showed the same pattern (clean → 1 miss across identical builds). | Engine EXONERATED as the max owner; the plan's "lead, not proof" framing confirmed with evidence. No engine/feedback change justified (nothing to eliminate; any change would risk feedback richness for zero gain). | None | Source run, `20260914T234527Z` (97.8/3) | Pending full pass | Closed for engine/projection (evidence-backed); `real-card-play` 41.6 ms and residuals classified system/Simulator. Drag-cancel protection holds — no Battle production code touched in this pass |

- [ ] Every high-priority finding has an evidence-backed disposition; remaining
  lower-priority rows are fixed, classified, or explicitly carried forward.
- [ ] One final optimized full pass has complete reports for the current inventory,
  with every remaining threshold finding disclosed and linked to its disposition.
- [ ] Relevant package/functional checks and scoped handoff pass; no save, reset,
  navigation, artwork, or feedback regression is accepted as a performance trade.
- [ ] Update canonical contracts for actual behavior changes. When the remediation
  work is complete, archive this plan under the Plans lifecycle and run
  `./Scripts/handoff.sh --isolate --final --paths <union-of-actual-changed-files>`.
  If intentionally handing off unfinished work, keep this plan active and use
  `--keep-plan`; document exact outstanding evidence rather than claiming closure.

This document itself is intentionally active: it is the requested handoff for a
future implementation agent, not a record that performance remediation has finished.

## Appendix: complete source-run inventory

Values below are observed callback metrics, not rendered-frame measurements.
`Missed` and `Severe` are counts within that step's own duration; do not rank count
alone across different durations. Sorted by maximum interval for discoverability;
use the priority queue and trace evidence to choose fixes. The original baseline
had minimum average and 1% low FPS of 59, zero severe stalls and missed deadlines,
plus the stricter gesture maximum. Only `hand-drag-cancel` met every goal.

| Scenario | Duration s | Max ms | Avg FPS | 1% low FPS | Missed | Severe |
|---|---:|---:|---:|---:|---:|---:|
| `equipment-search-filter` | 12.6 | 946.4 | 47.0 | 3.7 | 45 | 23 |
| `starter-companion-confirm` | 7.5 | 421.6 | 19.7 | 3.5 | 48 | 47 |
| `launch-animation` | 5.1 | 359.7 | 48.7 | 3.7 | 7 | 5 |
| `collection-navigation` | 7.6 | 345.0 | 55.0 | 8.6 | 12 | 4 |
| `equipment-picker-scroll` | 14.5 | 341.7 | 56.2 | 12.0 | 26 | 5 |
| `companion-detail-navigation` | 14.0 | 339.9 | 56.7 | 10.7 | 17 | 6 |
| `options-reset-confirm` | 5.0 | 250.1 | 55.6 | 8.4 | 6 | 2 |
| `tab-round-trip` | 12.1 | 221.3 | 56.4 | 9.9 | 15 | 7 |
| `defeat-save-recovery` | 4.3 | 207.2 | 53.7 | 7.5 | 6 | 4 |
| `battle-inspection` | 18.8 | 202.7 | 57.4 | 13.8 | 24 | 5 |
| `salvage-return` | 9.7 | 201.5 | 55.6 | 9.9 | 17 | 5 |
| `locked-character-offer` | 5.2 | 200.7 | 56.3 | 9.8 | 7 | 2 |
| `contracts-browse` | 11.7 | 198.7 | 57.3 | 13.4 | 15 | 4 |
| `talent-unlock` | 5.2 | 192.2 | 53.4 | 9.9 | 18 | 3 |
| `equipment-inspect-equip` | 7.2 | 186.1 | 50.1 | 6.8 | 29 | 11 |
| `campaign-stage-select-transition` | 4.2 | 184.8 | 55.7 | 11.2 | 8 | 1 |
| `stage-enemy-detail-transition` | 6.4 | 184.4 | 55.5 | 11.4 | 15 | 3 |
| `corruption-reveal` | 5.9 | 184.3 | 57.5 | 13.4 | 5 | 1 |
| `ability-picker` | 6.5 | 182.3 | 51.7 | 8.2 | 28 | 7 |
| `homestead-detail-transition` | 4.5 | 181.9 | 56.7 | 10.9 | 4 | 2 |
| `campaign-party-picker` | 11.7 | 166.6 | 55.6 | 12.7 | 27 | 6 |
| `campaign-chapter-progression` | 4.1 | 164.8 | 56.3 | 12.2 | 7 | 1 |
| `labyrinth-floor-progression` | 5.3 | 161.7 | 56.0 | 11.5 | 10 | 2 |
| `battle-retreat` | 6.7 | 159.0 | 55.2 | 9.2 | 11 | 4 |
| `postbattle-talent-reveal` | 4.2 | 157.9 | 54.5 | 9.1 | 9 | 2 |
| `labyrinth-shop-entry` | 4.7 | 156.3 | 56.2 | 9.1 | 4 | 3 |
| `collection-category-Heroes` | 12.1 | 156.0 | 57.3 | 14.0 | 15 | 5 |
| `options-reset-cancel` | 4.9 | 152.8 | 55.9 | 11.0 | 9 | 2 |
| `victory-claim-return` | 4.2 | 149.1 | 54.3 | 8.7 | 9 | 3 |
| `shop-purchase` | 5.3 | 147.3 | 55.0 | 9.5 | 11 | 3 |
| `recruit-map-reveal` | 7.3 | 139.0 | 57.1 | 13.0 | 8 | 2 |
| `collection-category-Basic Gear` | 15.0 | 138.6 | 57.7 | 15.5 | 15 | 5 |
| `mystery-reward-reveal` | 5.4 | 137.9 | 58.5 | 20.0 | 2 | 1 |
| `homestead-improvement` | 7.9 | 137.0 | 56.0 | 10.5 | 11 | 5 |
| `mystery-offer-inspection` | 6.7 | 136.5 | 58.1 | 14.6 | 5 | 2 |
| `contracts-battle-return` | 7.3 | 135.2 | 54.6 | 9.6 | 17 | 6 |
| `spire-climb` | 15.0 | 134.0 | 58.0 | 17.3 | 18 | 2 |
| `battle-log` | 18.0 | 133.7 | 58.2 | 17.8 | 17 | 5 |
| `talent-tree-scroll` | 10.8 | 131.6 | 56.4 | 14.7 | 23 | 6 |
| `homestead-build` | 6.6 | 124.8 | 57.0 | 12.5 | 8 | 3 |
| `defeat-retry` | 3.8 | 122.2 | 54.4 | 10.0 | 7 | 4 |
| `full-game-offer` | 5.3 | 116.7 | 57.2 | 14.0 | 5 | 2 |
| `campaign-full-game-boundary` | 5.6 | 112.0 | 55.2 | 14.3 | 18 | 2 |
| `postbattle-talent-choice` | 6.1 | 108.0 | 54.4 | 11.6 | 18 | 6 |
| `collection-category-Astral Gear` | 15.1 | 107.4 | 58.1 | 17.2 | 16 | 3 |
| `victory-reveal` | 7.0 | 105.9 | 58.3 | 19.0 | 7 | 1 |
| `contracts-party-picker` | 5.2 | 105.6 | 56.2 | 14.3 | 11 | 3 |
| `equipment-unequip` | 6.3 | 102.4 | 52.8 | 12.5 | 25 | 6 |
| `collection-category-Unique Gear` | 15.0 | 100.6 | 57.9 | 17.2 | 16 | 5 |
| `starter-hero-confirm` | 5.6 | 95.4 | 59.1 | 26.7 | 1 | 1 |
| `homestead-material-collection` | 9.9 | 92.8 | 58.3 | 18.4 | 9 | 3 |
| `labyrinth-boss-retreat` | 6.6 | 88.4 | 56.5 | 13.8 | 12 | 3 |
| `stage-select-battle-transition` | 4.6 | 86.0 | 56.7 | 13.6 | 8 | 3 |
| `homestead-category-browse` | 4.3 | 85.2 | 57.4 | 16.4 | 6 | 2 |
| `spires-browse` | 14.0 | 84.5 | 58.9 | 22.6 | 11 | 1 |
| `labyrinth-shop-return` | 5.5 | 83.3 | 58.4 | 20.2 | 5 | 1 |
| `options-controls` | 15.1 | 82.2 | 58.2 | 19.5 | 17 | 3 |
| `labyrinth-inspector` | 4.2 | 81.4 | 58.1 | 18.9 | 5 | 1 |
| `homestead-wallet-return` | 8.0 | 75.8 | 57.0 | 16.9 | 15 | 4 |
| `collection-category-Trinkets` | 15.0 | 74.4 | 58.4 | 19.7 | 16 | 4 |
| `labyrinth-floor-select` | 6.1 | 71.8 | 58.7 | 22.5 | 6 | 1 |
| `full-game-purchase` | 4.6 | 71.2 | 55.6 | 16.7 | 15 | 3 |
| `talent-reset-return` | 4.9 | 70.8 | 54.0 | 15.8 | 19 | 4 |
| `explore-hub` | 4.2 | 69.2 | 58.8 | 21.5 | 2 | 2 |
| `collection-category-Companions` | 14.9 | 68.4 | 58.4 | 19.9 | 15 | 4 |
| `defeat-reveal` | 5.7 | 67.3 | 58.6 | 22.0 | 6 | 1 |
| `corruption-item-picker` | 14.0 | 64.9 | 59.6 | 38.6 | 2 | 1 |
| `combatant-detail-scroll` | 11.9 | 63.0 | 58.7 | 21.2 | 11 | 2 |
| `labyrinth-boss-entry` | 3.9 | 62.1 | 57.4 | 17.7 | 6 | 2 |
| `shop-return` | 6.2 | 61.9 | 58.7 | 22.6 | 5 | 1 |
| `recruit-map-return` | 3.9 | 60.0 | 58.2 | 22.2 | 5 | 1 |
| `contracts-refresh` | 4.6 | 59.5 | 58.2 | 21.0 | 5 | 1 |
| `homestead-gallery-scroll` | 10.7 | 57.7 | 58.5 | 22.7 | 13 | 2 |
| `labyrinth-scroll` | 10.6 | 57.3 | 58.3 | 21.7 | 14 | 2 |
| `homestead-root-scroll` | 12.5 | 51.9 | 59.3 | 27.7 | 6 | 1 |
| `campaign-scroll` | 11.8 | 51.0 | 58.7 | 23.0 | 12 | 2 |
| `recruit-claim-return` | 4.0 | 50.0 | 58.0 | 22.4 | 6 | 1 |
| `engine-feedback` | 3.3 | 50.0 | 59.4 | 30.0 | 1 | 1 |
| `full-game-restore` | 5.2 | 48.7 | 59.0 | 26.4 | 4 | 0 |
| `collection-shelf-scroll` | 9.6 | 47.6 | 59.3 | 27.7 | 4 | 0 |
| `battle-auto` | 8.1 | 46.3 | 59.3 | 27.8 | 5 | 0 |
| `starter-carousel` | 8.5 | 44.3 | 59.6 | 40.0 | 2 | 0 |
| `shop-scroll` | 10.1 | 43.6 | 59.2 | 27.3 | 6 | 0 |
| `combined-worst-case` | 3.3 | 42.3 | 59.3 | 29.5 | 2 | 0 |
| `real-card-play` | 3.9 | 41.6 | 59.3 | 30.0 | 3 | 0 |
| `engine-hand` | 3.3 | 40.2 | 59.5 | 30.0 | 2 | 0 |
| `mystery-reward-claim` | 4.4 | 39.9 | 59.1 | 28.2 | 4 | 0 |
| `corruption-return` | 4.2 | 39.6 | 59.5 | 36.0 | 2 | 0 |
| `collection-browse-scroll` | 12.2 | 39.5 | 59.1 | 27.8 | 11 | 0 |
| `turn-transition` | 3.3 | 35.5 | 59.9 | 38.4 | 1 | 0 |
| `hand-drag-cancel` | 3.8 | 16.7 | 60.1 | 60.0 | 0 | 0 |
