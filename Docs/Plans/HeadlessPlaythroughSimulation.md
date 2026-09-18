---
type: execution-plan
status: active
created: 2026-09-18
updated: 2026-09-18
expires: 2026-10-02
---

# Headless Playthrough Progression Simulation

## Objective and feasibility

Build a virtual player that develops a real Trinket save through encounters,
battle rewards, equipment, talents, and Homestead improvements. Use production
commands to discover progression blockers, duplicate awards, persistence failures,
and economy or difficulty cliffs across reproducible scenarios.

**Feasible, with an existing foundation; full-career throughput is unproven.**
Source review on 2026-09-18 found a native macOS combat sweep, a shared combat
policy, and isolated AppState tests that connect real battle sessions to production
progression and saves. A full playthrough runner does not exist yet. The main work
is driving the complete lifecycle, controlling nondeterministic inputs, and
capturing replayable evidence—not rewriting combat in another language.

This adapts the sibling Alchemy plan at
`../Alchemy/docs/Plans/HeadlessPlaythroughSimulation.md` as reviewed on 2026-09-18.
Its virtual-controller architecture, bounded careers, replay, and staged reporting
transfer well. Its React/Node execution model, hero catalog, keyword drafting,
run resets, and browser storage assumptions do not describe Trinket.

This document is the requested implementation proposal. Implementation phases
remain pending; this documentation task does not authorize a platform port or
change standing balance/CI policy.

## Verified foundation and open questions

| Existing owner / evidence | What it provides | What remains to prove |
|---|---|---|
| [BattleEngine package](../../Packages/BattleEngine/Package.swift), [balance sweep](../../Scripts/balance-sweep.sh) | macOS-capable engine, app-unlinked `BattleBalanceTools`, optimized CLI workers | Complete-career execution cost, beyond isolated synthetic matchups |
| [PlayerPolicy](../../Packages/BattleEngine/Sources/BattleEngine/PlayerPolicy.swift) | `PlayPolicy.greedy` and `.setupAware` rank playable cards using production battle state | A session command adapter and suitable policies for non-battle choices |
| [AppTestContext](../../Packages/TrinketAppState/Tests/TrinketAppStateTests/Support/AppTestContext.swift) | Private store/defaults, silent `BattleSession`, real progression closures | Fresh onboarding without fixture conveniences, teardown of all pending work, full career loop |
| [Battle runtime](../AgentContext/battle-runtime.md), [launch/completion](../AgentContext/battle-launch.md) | Launch preparation, settlement, victory claims, defeat Retry/Leave, completion independent of view appearance | Advance required completion work without waiting for presentation timing |
| [Persistence configuration](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStoreConfiguration.swift) | Real SwiftData graph with in-memory or explicit file URL storage | Recorded close/reopen checkpoints and failure injection within careers |
| [AppState package](../../Packages/TrinketAppState/Package.swift), [BattleFeature package](../../Packages/TrinketBattleFeature/Package.swift) | Existing test composition spans orchestration and concrete battle session | Both declare iOS support; a full native macOS host has not been compiled or validated here |

“Headless” initially means **no SwiftUI view tree, rendering, taps, artwork/audio
playback, or cinematic waits**. It may still use an iOS Simulator test process and
Apple frameworks. “No Simulator required” is a separate, later portability goal.
Persistence already declares macOS support; this is not evidence that the entire
AppState/BattleFeature dependency graph works as a macOS executable. No Linux
support is proposed.

## Architecture: a virtual controller, not another game engine

```text
Production observations and legal choices
                 ↓
       Virtual player policy
                 ↓
Mode / encounter / battle-session / save commands
                 ↓
 Production rules, settlement, and SwiftData
                 ↓
     Assertions, journal, and metrics
```

- Production owns eligibility, prices, RNG, effects, reward settlement, mode
  completion, transaction boundaries, and save repair. The harness ranks choices,
  supplies player inputs, controls its environment, and records outcomes.
- A low-level effect applier is insufficient when the actual action also validates
  an offer, spends resources, settles rewards, or completes a node. Drive that
  complete action. Extract a small shared production operation only if a required
  sequence currently lives in a view; use it from both callers.
- Do not insert victories, grant progression, rewrite inventories, skip inconvenient
  encounters, or call mode completion directly in a fresh-save career. Fixtures
  can prepare targeted scenarios, with that origin explicitly recorded.
- Observe offers once through their real production flow. Scoring cannot reroll
  stock, consume gameplay randomness, or mutate the save. Policy observations
  contain only player-visible information; internal diagnostics remain separate.
- Reuse `PlayPolicy` for battle decisions, then submit card and turn commands to
  the real `BattleSession`. Running `BattleSimulator.run` and copying its result
  into progression would bypass session claims and is not a complete playthrough.
  Its synthetic matchup builders remain useful for isolated combat investigations.
- Treat a rejected expected-legal command as evidence to classify. Do not inherit
  the isolated simulator's fallback from a failed card play to an end turn without
  reporting it. Likewise, capped battles are incomplete, even when an underlying
  result uses defeat as an unresolved-outcome fallback.

### Ownership and execution host

Start with internal harness helpers and Swift Testing cases under
`Packages/TrinketAppState/Tests/TrinketAppStateTests/`, beside `AppTestContext`.
That target already permits the concrete BattleFeature dependency required for
real lifecycle integration. Keep production contracts narrow and follow the
[architecture map](../Platform/Architecture.md) and
[architect skill](../../.agents/skills/architect/SKILL.md).

Do not add Persistence or AppState dependencies to BattleEngine, put orchestration
in `BattleBalanceTools`, import the app module into a package, or make AppState
production code depend on BattleFeature. `BattleRuntime` is currently a lifecycle
contract, not a card-control API; use the concrete session in the permitted test
composition rather than extending it with harness-only controls.

The concrete session's `playCard`, `endTurn`, and `engineState` are currently
internal. Prove `@testable import TrinketBattleFeature` in the AppState test target
in Phase 0; its existing ordinary import does not expose these controls. Keep this
adapter in tests. A later standalone host needs a separately reviewed access
contract, not an assumption that the test adapter compiles in a release executable.

Phase 0 records whether existing injection points can disable presentation work
and drive progression to quiescence. `.silent` dependencies alone do not prove
all timers, automatic turns, feedback, and outcome tasks are disabled. Keep
`@MainActor` commands on their actor, await required asynchronous saves, and avoid
blocking the executor while waiting for completion. Do not accelerate by skipping
work that authorizes or finishes a gameplay transition.

Give each battle one command driver. Do not run the virtual policy alongside the
session's auto-battle driver. Account for scheduled auto-end turns even when
auto-battle is off: either drive their production transition deterministically or
observe and journal it before choosing the next action. Wait for session command
readiness, not just engine card legality; `endTurn` can return without advancing.
Record the command result and resulting transition so a presentation lock cannot
silently consume the action budget or be mistaken for a gameplay rejection.

Use the existing managed Simulator package-test route first. If its measured
throughput is inadequate, evaluate a native macOS composition host. That host must
reuse the same production action flow and requires a concrete dependency/compile
spike before choosing its package location. Do not create a second headless battle
runtime with copied lifecycle logic. Any necessary extraction or platform expansion
must satisfy the [deferred-seams criteria](../../.agents/knowledge/patterns/architecture-deferred-seams.md).

## First useful deliverable

One bounded **fresh-save career**, with one legal Hero/Companion pair:

1. Perform real starter selection and retain the new save.
2. Enter a reachable Campaign encounter through its production mode action.
3. Play the battle, settle victory or defeat, finish required reward/talent choices,
   and return to Play through production lifecycle commands.
4. Close and reopen the actual private save store at a supported safe boundary.
5. Enter and settle a second encounter or permitted retry using the earned
   progression; compare meaningful saved state with uninterrupted execution.

Define the first objective as two settled battle attempts with a supported reload
between them, including a legal retry if the first attempt loses. Record earned
progress and whether Campaign advanced; two defeats can prove lifecycle continuity
but cannot establish a victorious Campaign progression path. Use the same starting
inputs and policy for the uninterrupted comparison, with the reload as the only
intentional difference. Both branches must reach and settle the second attempt.

Compare semantic saved state immediately before closing and immediately after
reopening, before another gameplay command can hide a lost write or changed offer.
Then compare the next legal choices and the second attempt's settled state with
the uninterrupted branch. Declare comparison fields and justified metadata
exclusions up front; matching only the final outcome or total currency is
insufficient. Keep automatic load repairs observable in this comparison.

For the reload comparison, finish defeat with Leave, reopen at the browsing
boundary, and relaunch the still-available encounter through its mode action in
both branches. The defeat overlay and its Retry command are transient; test Retry
separately without assuming that button survives reopening the save.

Cover every mandatory choice reachable in this slice, including a Mystery or Shop
if encountered; unsupported choices end the scenario as incomplete. Keep both
victory and defeat settlement cases. A targeted quick-win fixture may establish
victory lifecycle correctness before the bot can win from a fresh save, but it
cannot substitute for earned-progression evidence.

A Trinket career is a bounded sequence of encounters and between-encounter actions
on one persistent profile. Campaign and Spires have permanent completion,
Labyrinth continues across floors, and Contracts renew. There is no universal
Alchemy-style run reset or “complete the infinite mode” success condition.

## Coverage tailored to Trinket

Use [product overview](../Product/Overview.md), production catalogs, and the mode
owners for actual choices. Expand a representative matrix, not a Cartesian product
of every party, mode, talent, item, and seed.

| Area | Actions and properties to exercise |
|---|---|
| Party and Collection | Starter selection, earned recruitment/unlocks, legal Hero/Companion changes, independent progression, talent prerequisites, equipment changes and inventory operations exposed by production |
| Campaign (`Journey` in code) | Reachability, stage/chapter completion, first and repeat rewards, Shop/Mystery transitions, return navigation |
| The Spires | Floor availability, fixed encounter-level rules, victory advancement, defeat/retry, permanent completion and repeated claims |
| Labyrinth | Generated persistent maps, reachable nodes, encounter claims, floor transitions, party health/state behavior, saved-map recovery, bounded depth horizon |
| [Contracts](../Product/Contracts.md) | Refresh, retained targets across party changes/reload, launch-time levels, victory replacement of one offer, defeat/retreat retention, stale offer rejection |
| Battle lifecycle | Launch-baked party/rewards, card/turn commands, victory Loot All, defeat Retry/Leave, retreat, stale configurations and settlements, pending presentation exit |
| Shop and Mystery | Production availability, pinned offers and prices, purchases, stock after reload or item removal, legal choices and deliberate leave, effects plus completion in one action |
| Talents and equipment | Spend earned points, choose legal builds, equip earned items, verify their effects in subsequent launch inputs; add salvage/corruption coverage where applicable |
| [Homestead](../Product/Homestead.md) | Affordable build/upgrade with displayed target tier, prerequisites, timed production, collection, wallet limits, rate changes and persisted benefits |
| Content access | Separate fresh free-access and simulated full-access cohorts; locked choices remain unavailable and saved progress survives access reconciliation |

Production owns encounter scaling and reward policy; link to
[battle balance](../AgentContext/battle-balance.md) and
[persistence progression](../AgentContext/persistence-progression.md) instead of
encoding those formulas in the harness.

`AppTestContext` normally skips starter selection and defaults to full access.
Fresh-save tests must opt into onboarding and explicitly declare content access;
never label the default fixture a free-player onboarding simulation. Simulated
ownership tests game access rules, not StoreKit purchase verification.

The current onboarding-environment overload also hardcodes the helper's default
full access and cached store. Add only the test-helper parameters needed to combine
onboarding, an explicit access policy, and an injected file-backed store. Verify
those inputs before the first starter choice; changing access after progression
has started does not establish a fresh free-access cohort.

### Policies and player-like interpretation

Start with a simple legal-choice progression policy and the existing greedy or
setup-aware combat policy. Later add a small number of strategies that exercise
different decisions: cautious progression, talent/equipment synergy, Homestead
investment, roster rotation/catch-up, and seeded random legal choices.

Trinket's Hero/Companion loadouts, talents, equipment, and three-card-hand combat
are the relevant inputs. Do not import Alchemy's thin-deck/removal heuristics or
its hero/archetype catalog. Add keyword preferences only where current production
choices support them and evidence shows the policy exercises the intended mechanic.

Policy RNG is separate from gameplay RNG. A deliberately omniscient diagnostic
policy must be labeled and excluded from player-like balance estimates. Bot loss,
resource hoarding, poor matchup selection, and unsupported policy choices are not
by themselves game-balance defects.

## Determinism, isolation, and persistence

### Reproducible execution

Record a scenario manifest with starting save/fixture version, world seed, combat
seeds, policy seed/version, access mode, bounded objectives, and simulated time.
Audit every random, date, ID, and asynchronous input on the exercised paths.
`PlaySession+BattleLaunch` currently chooses random combat seeds outside its perf
fixture path; defeat settlement uses `Date()`, and other save actions have date
inputs or internally generated timestamps. One seed flag is insufficient.

Inject or record the smallest necessary production inputs. Preserve separate
world/combat/item/policy streams and the existing seed contracts. IDs used in
claims and action references need reproducible generation or explicit replay
mapping; do not remove identity checks to obtain matching traces. Exclude only
proven non-gameplay metadata from semantic comparisons.

A checkpoint also needs harness continuation state: policy memory, random-stream
positions or recorded-input cursors, simulated clock, and remaining budgets. Initial
seeds alone cannot resume an already-consumed stream. Keep this state in the replay
bundle, outside the shipping save schema; otherwise replay from career start.
The reload comparison must preserve the same harness continuation in both branches
so it measures save recovery rather than a restarted policy or random sequence.

Use explicit simulated dates for Homestead accrual and record session/offline
cadence. Fast CPU execution must not imply faster production. Control retry and
presentation scheduling separately from economic time, await required work, and
never sleep through real-world production intervals.

Each career owns its store URL, recovery files, defaults suite, runtime objects,
clock/RNG inputs, and pending tasks. Cloud sync and audio are disabled. Never use
the player's default save location, iCloud account, or real purchase flow. Start
sequentially; prove A-alone equals A-after-B with complete teardown. If reliable
reset is costly or incomplete, use a fresh owned worker/test process per career.
Parallel workers are a later optimization and cannot share save containers.

Make broad career sweeps explicitly opt-in when introducing the test harness,
before adding a standalone wrapper. The existing package runner executes package
tests by default; placing sweeps in the AppState test target does not make them
manual. Verify that the ordinary package route runs only the bounded correctness
set and that the opt-in route reports the requested scenario count. Establish
sequential execution explicitly for the isolation proof; actor isolation alone
does not prevent asynchronous careers from interleaving.

### Real saves and supported recovery

Use the actual `PlayerSaveStore` and SwiftData graph. In-memory stores can support
cheap rule exploration, but persistence scenarios use a temporary file-backed
store and a **new container/store instance** after close/reopen. Reusing the cached
`AppTestContext` save or comparing a Codable value with itself does not test disk
persistence. Private storage is a relocation of the shipping local backend, not a
replacement dictionary implementation.

`AppTestContext` normally creates an in-memory store. Its `-reset-state` branch
uses disk but resets the profile, so it is not a reload mechanism. Inject the
private file-backed store explicitly, then reopen the same URL without reset after
releasing the old session, store, and pending work. Preserve or deliberately restore
the private defaults alongside the store when they influence the next action.

Checkpoint capture must preserve a coherent durable store, including any required
database sidecars and authoritative pending-save record. Do not copy only the main
database file while a writer is active. Prove the capture/restore procedure by
opening the bundle in a fresh process. Keep raw recovery evidence intact; loading
and re-saving a value snapshot is not equivalent to preserving a failing store.
Archive the captured bundle before opening it, and replay or inspect a disposable
copy. `PlayerSaveStore` initialization can restore a pending record, repair the
graph, and retry persistence; opening the sole evidence copy can change the failure
being investigated.

Check the produced save before and after loading, including graph relationships,
Labyrinth payload, inventory/equipment references, roster, claims, and progression.
Detect unexpected sanitizer repairs or dropped fields, adding a narrow diagnostic
seam if current results do not expose them. Stable round trips alone cannot prove
that the first load preserved the data. Keep intentional corruption fixtures
separate and assert their documented repairs.

**Trinket does not promise active-battle resume.** Follow the
[launch/completion contract](../AgentContext/battle-launch.md): restart from the
last committed progress, preserving an unclaimed encounter for retry where its
mode promises that behavior. Do not add a mid-battle save schema for this harness.
Compare uninterrupted and reloaded continuations only at supported save boundaries.
An interruption during combat or reward presentation checks the documented
recovery outcome, not exact restoration of transient session state.

Test last-written-state recovery without forcing a final save. Selected cases
cover victory/defeat settlement, offer replacement, and shop claims around failure
boundaries; assert no lost committed award and no duplicate charge/grant. Exercise
pending-save recovery and total-write-failure compensation through the existing
[storage contract](../AgentContext/persistence-storage.md), rather than assuming
SwiftData success is the only accepted durable write.

Distinguish orderly reopen, scene backgrounding, and abrupt process termination.
`AppState` flushes pending persistence on inactive/background transitions, so those
callbacks cannot simulate termination without a final save. For abrupt-interruption
coverage, stop an owned worker at a recorded boundary without invoking lifecycle
cleanup; preserve its private files before fixture teardown can delete them. Label
in-process fault injection separately from process-termination evidence, and check
recovery from the captured files in a new process.

Local-only Homestead careers do not verify CloudKit-authoritative claims, account
switches, or server receipts. Existing transport tests and the separate
[CloudKit readiness checks](../Platform/CloudKitPreShipChecklist.md) retain that
responsibility. Headless execution also does not prove UI wiring, accessibility,
art/audio, physical-device behavior, or StoreKit delivery.

## Invariants, limits, and failure evidence

Keep cheap invariants after every action; run close/reopen checks at each covered
safe boundary in the small correctness suite. Larger sweeps may use a recorded
persistence sampling interval, with mandatory checks at career boundaries.

- Rewards, purchases, encounter completion, and Contracts replacement occur at
  most once for the same production claim identity.
- Stale configurations, repeated claims, outdated Homestead target tiers, and
  newly unaffordable purchases follow production rejection contracts without
  unintended changes. Exercise these in targeted cases outside balance cohorts.
- Legal resource/health bounds and finite calculations hold; relationship IDs and
  active equipment remain valid. Independent assertions check properties without
  maintaining a second set of damage, price, or XP formulas.
- Bound battle rounds/actions, repeated no-op decisions, encounter attempts, career
  steps, simulated time, and artifact size. Use an external watchdog for hangs;
  an in-process timer cannot reliably stop a blocked synchronous operation.
- Record battle outcomes (victory, defeat, retreat) separately from career
  termination (completed objective, invariant failure, persistence failure,
  unsupported choice, policy stall, budget exhaustion, crash, watchdog timeout).
  Defeat may continue through Retry/Leave and can satisfy an expected defeat case;
  it does not automatically terminate a career or fail a correctness test. Each
  scenario declares its objective and expected assertions before execution. A
  required scenario that is incomplete cannot pass. A bounded timeout is not proof
  that the game is unwinnable or softlocked.

Write each attempted action before invoking it. Persist the last restorable
checkpoint plus every action since it, including the failing action, meaningful
state summaries, seeds/controlled inputs, policy/settings, and code/content
identity (commit plus dirty-change identity). Flush journal evidence so a killed
worker leaves a useful record. Preserve the last good checkpoint if the failing
state cannot serialize. Stop as incomplete if the evidence budget would otherwise
require deleting the replay suffix.

Give attempted actions sequence IDs and append their results separately. An
interruption between the command and its result leaves an unknown outcome, not a
proven rejection; recover from the checkpoint and journal without blindly issuing
the action again against the potentially committed store. Record the host OS,
Xcode/Swift version, Simulator runtime, and artifact schema version with the bundle.

Inputs sampled inside a command must also survive that interruption: replay must
derive them from checkpointed deterministic sources or consume inputs durably
recorded before their gameplay use. Recording a random seed, date, or generated
claim ID only in the command's result loses it when the command crashes. If a
required input is missing, preserve the bundle and report replay as incomplete
rather than silently sampling a replacement.

A shipping save is a replay checkpoint only when loading preserves the next
recorded choice. For transient combat, replay from the earlier supported boundary
or career start with recorded launch inputs and card/turn actions. Replay executes
recorded actions, checks transitions, and reports the first divergence; it does
not rerun the policy. Demonstrate reproduction in a fresh process before claiming
determinism. Changed-code replay is a regression experiment, not guaranteed exact
reproduction. A controlled injected failure is sufficient to validate capture.

## Metrics and reporting

Build one structured outcome model for terminal summaries and JSON first; add a
shareable HTML report only after useful complete-career data exists. Keep schemas
and calculations shared. The existing battle sweep can inform metrics and worker
handling, but does not imply its thresholds apply to organic careers.

Report planned/completed/incomplete careers, reached choices and save boundaries,
party and policy, encounter/floor reach, win/defeat/retreat rates, rounds/actions,
resource earnings/spending, affordable opportunities, equipment use, and talent /
Homestead milestones. Track cards drawn, playable, and chosen separately. Include
unreached milestones and their career horizon; averaging only successes hides
slow progression. Show simulated days separately from encounters and CPU time.

Retain three distinct populations: fresh saves earning progression, targeted
fixtures covering late or rare states, and coverage-directed/failure searches.
Do not pool them into player win rates. Report boss success conditional on reaching
the boss alongside reach rates. Treat careers, not their correlated battles, as
independent samples for uncertainty estimates.

Baseline comparisons use a versioned scenario manifest and rerun the same policies
on both revisions. Decisions may change as gameplay changes; recorded action
replay serves a different purpose. Matching seeds do not guarantee identical paths
or RNG consumption. Report denominators, effect sizes, and uncertainty; confirm
anomalies on additional seeds and another policy before declaring balance defects.

Balance thresholds remain advisory until calibrated against both measured variance
and explicit design goals. Do not copy Alchemy's numerical alert examples. Existing
[battle sweeps are manual](../AgentContext/battle-balance.md); this plan preserves
that policy and creates no nightly automation or new balance CI gate. Small,
deterministic lifecycle regressions may join ordinary package correctness tests
under [Testing](../Platform/Testing.md) and [Verification](../Platform/Verification.md).

## Phased implementation and acceptance

### Phase 0 — Prove the lifecycle and measure the host

- [ ] Trace production callers and inventory required choices for the first slice;
  record presentation dependencies, entropy/date/ID inputs, and save boundaries.
- [ ] In the existing AppState test target, prove a real battle command and complete
  settlement, one Shop purchase, one Mystery choice, and one async Homestead action.
  Verify testable access to the session controls. Targeted fixtures are acceptable
  for this spike, clearly labeled.
- [ ] Drive required tasks to completion without UI or real presentation waits;
  preserve automatic completion/retry semantics and cancel pending work at teardown.
- [ ] Prove isolated A-alone/A-after-B results and file-backed reload. Choose
  teardown/reopen versus owned-process isolation, and prove that the chosen test
  route can export a checkpoint and reopen it in a fresh process. The full action
  journal and controlled-failure replay are Phase 1 work.
- [ ] Measure cold build/startup separately from warm battle/action, store commit,
  reopen, and reporting costs. Record an initial runtime and memory budget.
- [ ] Decide whether the Simulator host is sufficient. Only if needed, perform the
  macOS dependency/compile spike and document exact blockers and bounded changes.

**Exit:** demonstrated production-path integration and a host decision with measured
costs. No assumption that all iOS packages are portable or timers are harmless.

### Phase 1 — One fresh career and failure recorder

- [ ] Implement the starter-to-two-encounter career and every mandatory reachable
  choice, with one party and simple policies, no progress injection or seed culling.
- [ ] Add bounded execution, flushed action journal, scenario manifest, replay,
  semantic invariants, terminal summary, and JSON with distinct incomplete outcomes.
  Verify that broad sweeps require explicit opt-in and ordinary package tests
  retain only the bounded correctness set.
- [ ] Retain victory, defeat Retry/Leave, retreat, stale/duplicate claim, and one
  interruption-at-settlement case; use targeted fixtures where necessary.
- [ ] Compare a supported save/reopen continuation against uninterrupted play and
  validate last-written-state recovery without a forced final save. Preserve
  harness continuation state, compare immediately after reload and after the next
  settled attempt, and replay from disposable copies of captured stores.
- [ ] Prove one abrupt owned-worker interruption and fresh-process recovery,
  separately from orderly reopen, backgrounding, and in-process fault injection.
  Include an interruption after a command consumes a nondeterministic input but
  before its result is journaled; replay must retain that input or report the gap.
- [ ] Measure complete-career throughput, including persistence and diagnostics;
  size the fixed correctness set from this measurement, not combat-only speed.

**Exit:** the fresh career completes its bounded objective, targeted lifecycle
cases pass, failures reproduce in a new process, and incomplete cases cannot appear
as successful sweeps. Poor bot strength is reported separately from lifecycle bugs.

### Phase 2 — Earned investment and time

- [ ] Extend a fresh career until it earns an affordable talent, equipment, or
  Homestead improvement; purchase/equip through production commands, reload, and
  confirm the intended benefit through its production consumer: the next battle's
  launch inputs for combat bonuses, or timed accrual/collection for production.
- [ ] Cover timed Homestead collection and rate changes with recorded session cadence.
- [ ] Exercise party rotation, catch-up progression, wallet capacity, and inventory
  choices with a small targeted set, using production queries and commands.
- [ ] Cover free-content boundaries and simulated full access as separate cohorts.

**Exit:** demonstrated earn → invest → persist → benefit loop. Late upgrades may use
fixtures, with no claim that fixture-granted progress proves fresh-save pacing.

### Phase 3 — Modes and representative strategies

- [ ] Extend Campaign, Spires, Labyrinth, and Contracts through their distinct
  transitions and claims; use bounded horizons for renewable/infinite modes.
- [ ] Expand Shop/Mystery and collection coverage; retain rare rejection/recovery
  scenarios rather than depending on random rediscovery.
- [ ] Add party/strategy profiles only when they cover distinct behavior; report
  reached content and unsupported paths explicitly.
- [ ] Add selected storage-failure/retry cases to career boundaries, preserving
  existing focused persistence tests rather than duplicating their full matrix.

**Exit:** a documented mode/choice coverage matrix with known gaps and reliable
replay; no requirement to exhaust every possible build or infinite depth.

### Phase 4 — Tooling, comparison, and optional native host

- [ ] Add an on-demand wrapper only after the host/entry point is proven. Proposed
  name: `Scripts/playthrough-sweep.sh`, with scenario, seed, horizon, output, and
  replay-bundle options. It does not exist yet; finalized commands belong in Scripts.
- [ ] Keep generated reports/replay bundles in a dedicated gitignored output
  directory; keep small retained scenario manifests/fixtures with their test owner.
- [ ] Implement baseline comparison and richer economy/progression diagnostics;
  add HTML last, using the same structured data as terminal and JSON outputs.
- [ ] If measurements justify a native host or parallel workers, preserve the exact
  production flow, demonstrate parity against retained Simulator cases, and measure
  end-to-end gains before adopting the change.
- [ ] Keep broad balance sweeps manual. Any future scheduling or balance gating
  requires a separate decision and an update to its canonical policy owner.

## Documentation-task verification and handoff

This plan is grounded in source and contract review, not a new compilation or
simulation benchmark. Phase 0 is where feasibility becomes executable evidence.
No production Swift, save schema, package manifests, or CI configuration changed.

Run the scoped documentation handoff and intentionally retain this active plan:

```sh
./Scripts/handoff.sh --isolate --final --keep-plan --paths Docs/Plans/HeadlessPlaythroughSimulation.md
```

Implementation should reroute the actual touched paths and run their required
checks. Keep durable behavior in its existing owner rather than promoting this
proposal into standing policy. On implementation completion or cancellation, follow
[the plan lifecycle](README.md): record the outcome in the archive and remove the
active plan, retaining its history in Git.
