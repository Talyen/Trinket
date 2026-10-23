---
type: execution-plan
status: active
created: 2026-10-23
updated: 2026-10-23
expires: 2026-11-06
---

# Complexity simplification

## Objective and status

Make ordinary changes to saving, card inspection, damage rules, and combat motion
easier to reason about without changing Trinket's rules, saves, presentation, or
player feedback. Reduce independently maintained representations of the same rule;
preserve the package DAG and existing ownership boundaries.

Implementation of all four simplifications is authorized, in order: motion
recipes, explicit retry results, shared card semantics, then damage packets.
All four simplifications are implemented. Static checks passed through shared card
semantics; damage-packet checks and complete compiled/behavior/visual verification
remain in progress. Shipping-UI inspection awaits the occupied managed simulator
slot. Review, local integration, and plan closure remain outstanding.

Reviewed baseline: committed local main `2ad7f9db7`. Evidence comes from production
source, callers, contracts, and existing regression tests. These are maintenance
findings, not confirmed gameplay bugs. No runtime performance improvement or visual
equivalence is claimed. Package tests, app compilation, simulator inspection, and
device profiling were not run for this analysis-only pass.

## Priorities and sequence

The largest costs are hidden retry control flow, a growing second interpretation
of card behavior, and dispersed interpretation of damage flags. Animation recipes
offer a smaller, contained simplification to establish a safe first result.
All findings are P2 maintenance improvements under the audit rubric. Priority here
means refactoring value, not evidence of current progress loss or broken gameplay.

| Priority | Area | Demonstrated avoidable cost | Target outcome | Relative effort / risk |
|---|---|---|---|---|
| 1 | Save-action retries | Callbacks return product results while retry decisions come from a dynamically installed store recorder | Retry disposition follows an explicit command result | Large / high; Persistence and feature callers |
| 2 | Card assessment | Inspection repeats composite-effect and resource-order knowledge owned by execution | Share narrow semantic decisions; retain conservative uncertainty | Medium to large / high; misleading cues are player-visible |
| 3 | Damage operations | Mutable exceptions interpreted across pipeline and Unique handlers | Explicit packet construction and shared eligibility decisions | Large / high; combat order and RNG must remain exact |
| 4 | Combat motion recipes | Parallel transform arrays repeat timing and use positional fallbacks | Named timed poses; independent rotation where needed | Small to medium / moderate; motion parity required |

Recommended landing order: **4, 1, 2, 3**. Each can ship independently. Do not
combine them into a single rewrite or make one wait for a general framework.
Effort is comparative, not a calendar estimate; there is no measured deletion or
performance forecast yet.

## 1. Make save retry results explicit

### Evidence and cost

[PlayerSaveStore+Retry.swift](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore+Retry.swift)
accepts an arbitrary `Value` from `performSaveAction`, but that value does not
determine retry behavior. `attemptSaveAction` installs mutable `saveActionAttempt`
state on the store, restores its predecessor with `defer`, and reads failures
recorded by `commit` and `notePersistenceFailure` in
[PlayerSaveStore+Persistence.swift](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore+Persistence.swift).
[SaveActionRetryQueue.swift](../../Packages/TrinketPersistence/Sources/TrinketPersistence/SaveActionRetryQueue.swift)
uses that hidden failure to retain and rerun the callback.

For example, `beginShopEncounter` converts a persistence failure to `.unavailable`,
and `beginShopOrAutoComplete` returns `nil` for it in
[EncounterPlayMode.swift](../../Packages/TrinketAppState/Sources/TrinketAppState/Play/Modes/EncounterPlayMode.swift).
The shop still retries because the store recorded a failure during that call.
The same visible return can mean a finished no-op or retained work. Understanding
this requires following the callback, transaction, recorder, attempt, and queue.

There are 22 production `performSaveAction(...)` call expressions across 13 Swift
files in this baseline, including views, AppState modes, and Persistence. This
count identifies migration scope; the finding is the hidden behavioral dependency.
The awaited `retryingSaveTransaction` already retries a typed `.persistFailed`
result. Its awaited lifecycle and the queue's retained-intent lifecycle differ
and should remain distinct.

### Target design

Keep scheduling in Persistence and navigation/feedback in their feature owners.
Each scheduled attempt explicitly returns its product value and retry disposition,
derived from its command's typed transaction result. Prefer existing
`SaveTransactionResult`; add at most one small attempt value where an adapter must
preserve a synchronous product return while scheduling subsequent work.

Keep keyed submission identity, generation invalidation, cancellation, and backoff.
Remove the ambient recorder after migrating the last caller. Do not replace it
with TaskLocal state, a workflow framework, or diagnostic polling.
`lastPersistenceError` remains diagnostic only.

### Migration steps

1. Inventory the 22 callers. For each, record the immediate value, retry condition,
   ownership check, committed unit, and delayed feedback. Distinguish single
   transactions from workflows containing several commits.
2. Start with `recordBattleEncounter` in
   [PlayerSaveStore+Library.swift](../../Packages/TrinketPersistence/Sources/TrinketPersistence/Progression/PlayerSaveStore+Library.swift).
   It already receives a typed transaction result and discards it. Let the queue
   consume that result explicitly. Keep the old path only during migration.
3. Migrate shop purchase/leave, then opening and Mystery resolution. Preserve
   product result enums at UI boundaries; carry storage failure through private
   helpers until scheduling has decided what to retain.
4. Migrate victory/defeat, remaining modes, roster/party/talent edits, starter
   selection, salvage, reset, and debug callers. Preserve prompt pending feedback;
   publish completion feedback/navigation only for the committed unit.
5. For multi-step workflows, retry the unfinished step. Do not replay a successful
   opening because a nested reward failed. Make any aggregation explicit and local:
   a later success cannot erase an earlier failure, and terminal validation failure
   wins over transient failure. Nested retry intents retain independent ownership.
6. Delete the store's `saveActionAttempt`, the recorder class and its writes from
   commit/logging, and the old callback-only scheduling API. Remove temporary
   adapters and update the retry contract in the same final landing.

### Verification and acceptance

Reuse
[PendingSaveRecoveryTests.swift](../../Packages/TrinketPersistence/Tests/TrinketPersistenceTests/Storage/PendingSaveRecoveryTests.swift):
replacement even when no write occurs, reset invalidation, reentrant replacement,
obsolete callbacks, nested reward retries, and failure followed by success. Retain
independent disk reload assertions. Add only missing coverage for the new boundary.

Run routed Persistence tests and affected AppState integration tests, then compile
the app for cross-package callers. Exercise delayed shop, Mystery, victory, and
defeat feedback with controlled storage failures through existing journeys or a
bounded managed inspection.

Done means scheduling follows the attempt's returned result, no ambient recorder
remains, and domain commands no longer need to know an enclosing closure might be
collecting their errors. Do not force both retry lifecycles into one abstraction.

## 2. Share card semantics between inspection and execution

### Evidence and cost

[BattleCardAssessment.swift](../../Packages/BattleEngine/Sources/BattleEngine/Cards/BattleCardAssessment.swift)
has specific branches for Blessed Aegis, Panacea, Pack Tactics, party preparation,
each-ally effects, and recipients affected by preceding work. Corresponding
execution behavior lives in
[EffectApplication.swift](../../Packages/BattleEngine/Sources/BattleEngine/EffectApplication.swift),
[BlessedAegisHandler.swift](../../Packages/BattleEngine/Sources/BattleEngine/EffectHandlers/BlessedAegisHandler.swift),
[CardDrawHandlers.swift](../../Packages/BattleEngine/Sources/BattleEngine/EffectHandlers/CardDrawHandlers.swift),
and ordered turn resolution.

Blessed Aegis execution expands the effect into Block and a Holy ward for living
allies; assessment reconstructs those same constituents. Panacea assessment
separately knows cleansing can trigger reactions before selecting the healing
recipient. These are concrete co-change obligations even where today's
conservative results are correct.

[BattleCardAssessment+Resources.swift](../../Packages/BattleEngine/Sources/BattleEngine/Cards/BattleCardAssessment+Resources.swift)
reconstructs abilities to obtain empowerment quotes. `hasPredictableRepeatedPayments`
clears known passive trigger fields and compares the remainder to an empty trigger
structure. This is conservative, but couples quote certainty to unrelated catalog
additions.

Useful sharing already exists:
[BattleAbilityRules.swift](../../Packages/BattleEngine/Sources/BattleEngine/Actions/BattleAbilityRules.swift)
owns conditional/fallback outcome selection, and `ManaEmpowermentBudget` owns payment
calculations. Extend these narrow seams rather than replacing them wholesale.

### Target design

Within BattleEngine, share the semantic facts both paths need: composite effect
constituents, recipient-selection rules, and whether recipients/payments depend on
preceding mutation or reactions. Execution reevaluates live state at the correct
checkpoint. Assessment consumes read-only rules and promises only facts certain
across eligible branches.

Keep unknown cases unknown. Do not introduce a full speculative battle simulator,
enumerate every reaction combination, or peek at future RNG. A replacement for the
conservative trigger check must remain conservative when new triggers appear.
Improving cue precision is a separate behavior change, not part of this refactor.

### Migration steps

1. Characterize existing targets, payers/amounts, denials, and unchanged live state
   and RNG using current regression cases.
2. Share Blessed Aegis's constituent effect description first. Execution retains
   iteration and live-health checks; a captured target list cannot override nested
   reactions. Assessment reads the same constituent description.
3. Share narrow recipient policy for Panacea and party preparation, including the
   selection checkpoint. A helper that simply returns the initial lowest-Health
   ally would be wrong. Keep Pack Tactics's post-hit draw choice uncertain where
   stability cannot be established.
4. Reuse ordered `AbilityOperation` values when reasoning about preceding work,
   rather than reconstructing order from filtered damage/effect arrays. Preserve
   the existing public assessment output and its conservative certainty.
5. Give `ManaEmpowermentBudget` an explicit read input where this removes synthetic
   `Ability` reconstruction. Evaluate a local certainty policy against the current
   check. If it requires a parallel trigger catalog or turns unknown into certain
   without proof, keep the current check and stop this substep.
6. Delete replaced projections. Retain common-resource and branch-intersection
   logic, which represents real uncertainty. Update the owning behavior contract.

### Verification and acceptance

Reuse
[BattleCardAssessmentTests.swift](../../Packages/BattleEngine/Tests/BattleEngineTests/Cards/BattleCardAssessmentTests.swift)
for random/common targets, unknown payments, shared discounts, repeated payments,
fallback affordability, reaction-sensitive Panacea, and capped Meteor quotes.
Compare deterministic facts with execution where meaningful; uncertain cues must
not promise a particular future. Inspection cannot mutate RNG, hand, roster, or
command output.

Run BattleEngine tests and compile affected consumers. Inspect shipping target and
resource cues for deterministic, random, and reaction-sensitive cards. Done means
a supported composite-effect change no longer requires independently rewriting
its meaning in assessment and execution. Moving the same cases into an
assessment-only registry does not qualify.

## 3. Make damage packet meaning explicit

### Evidence and cost

[DamageOperation.swift](../../Packages/BattleEngine/Sources/BattleEngine/Damage/DamageOperation.swift)
already has useful factories and a private operation kind. It also carries mutable
flags for copied damage, redirection, natural ticks, repeat capture, leech
suppression, and deferred elemental settlement. `isResolvedCardRepeat` is inferred
from repeat capture plus resolved scaling. `repeated(...)` copies the operation
and manually resets selected properties.

Interpretation is distributed through
[DamagePipeline.swift](../../Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipeline.swift),
its offense/post-reaction steps, and
[UniqueCombatEngine+Damage.swift](../../Packages/BattleEngine/Sources/BattleEngine/Uniques/UniqueCombatEngine+Damage.swift).
Examples are distinct retaliation/counterattack combinations for reaction groups,
and resolved scaling further distinguished by copied-packet and card-repeat flags.
Adding a repeat variant requires auditing construction, inherited/reset state,
outgoing calculation, and reaction eligibility.

The issue is distributed interpretation, not file count. The ordered pipeline,
committed hit facts, and live checks after reactions are necessary and stay.

### Target design

Keep the pipeline; make related packet modes explicit in their construction and
transformations so handlers do not infer them from unrelated flags. Start with
copied/redirected/resolved-repeat cases and named operations that construct them.
Preserve orthogonal numeric modifiers and genuinely independent options rather
than forcing all combinations into an enormous enum.

Centralize only repeated eligibility decisions with identical meaning, named after
the rule they govern. Keyword-dependent or live-state-dependent decisions must
keep those inputs or stay at their checkpoint; do not cache them before reactions.
Avoid a configurable pipeline, rule DSL, protocol per phase, or second table of
every conditional. A type that merely wraps all old flags is not simplification.

### Migration steps

1. Inventory current constructors/transformations: ordinary and Unique card
   attacks, counters, repeated attacks, card/critical repeats, periodic/resolved
   ticks, reactions, copied/redirected packets, Health costs, and elemental damage.
   Record scaling, accuracy, capture, reaction eligibility, and payoff timing.
2. Preserve representative seeded command results before edits: state, RNG,
   event/action order, effects/resources, and claims. Final Health alone is weak
   parity evidence. Reuse existing fixtures and assertions.
3. Migrate one cluster first: Unique repeat capture and resolved replay. Keep
   public factories required by current consumers; remove old inference after
   migrating all readers.
4. Migrate copied and redirected packets, then natural ticks and settlement timing
   where explicit construction removes coupling. Have repeat construction state
   what it inherits and clears, replacing the open-ended clone/reset sequence.
5. Consolidate equivalent eligibility checks against the behavior inventory.
   Preserve handler-specific rules, live checks, saturation, and pipeline order.
6. Delete obsolete flags, mutation sites, and duplicate predicates. Update
   [the damage contract](../AgentContext/battle-damage.md) with final packet
   distinctions, not a duplicate implementation-level policy matrix.

### Verification and acceptance

Run BattleEngine coverage including `CardDamageBoundaryTests`,
`DamageCadenceRegressionTests`, `StatusDamageScopeRegressionTests`,
`ResolvedDamageRegressionTests`, `ElementalReactionTests`, and affected Unique tests.
Preserve borrowed Block, Death's Door, copied/reflected damage, defeated sources,
ticks versus detonations, and action/card/turn claim cadence. Compare seeded events
and RNG for each migration cluster; run routed downstream BattleFeature checks for
feedback implications.

Done means the meaning of copied/redirected/repeated packets is clear at construction
and the former inference/reset machinery is deleted. Keep the scope bounded if
further changes only exchange one collection of flags for another.

## 4. Replace parallel animation arrays with named timed poses

### Evidence and cost

[CombatFeedbackPresentationModels.swift](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/CombatFeedbackPresentationModels.swift)
stores separate sample arrays for scale X/Y, offset X/Y, and rotation. Hit getters
interpret positions zero/one as impact/recovery with silent fallback values;
attack getters interpret zero/one/two as wind-up/swing/recovery. Both read shared
phase durations from scale X.

[CombatFeedbackAttackRecipes.swift](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/CombatFeedbackAttackRecipes.swift)
repeats attack durations across all five tracks.
[CombatFeedbackCardRecipes.swift](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/CombatFeedbackCardRecipes.swift)
repeats ordinary hit-transform durations and separately supplies total duration.
[BattleCombatantPane.swift](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Battlefield/BattleCombatantPane.swift)
renders scale/offset with the common durations; the other transform-track durations
do not independently control their rendering.

A phase change requires synchronized edits to repeated values, while the model
permits mismatched lengths and ignored timing differences. Celebration is an
essential exception: its ten-sample rotation lasts longer than its two-phase
scale/offset movement and is independently consumed.

### Target design and migration

1. Reuse the `CombatantAttackPose` shape, or a small neutral internal pose if its
   name becomes misleading. Store scale, offset, and angle together. Retain scalar
   rotation samples for genuinely independent tracks.
2. Represent hits with named impact/recovery poses and one duration per phase;
   represent attacks with wind-up/swing/recovery poses and one duration per phase.
   Explicitly preserve the no-reaction recipe's current fallback recovery behavior.
3. Preserve celebration's independent rotation timeline and full visible lifetime.
   Distinguish scheduling lifetime from pose duration where consumers do; do not
   force them to sum to the same value.
4. Migrate constants, layout resolution, sampling, and scheduling together.
   Preserve spring/cubic choices, recoil/aim, preparation caps, interruption,
   reduced motion, suspension, and the approved
   [attack timings](../Product/CardPlay.md#turns-and-battlefield-effects).
5. Delete parallel transform arrays, positional getters, and obsolete fallbacks.
   Keep the renderer, scheduling queue, caches, and publication lanes intact.

### Verification and acceptance

Compare every recipe's effective poses, phase durations, rotation, and scheduling
lifetime. Reuse `BattleActionPresentationTests` and relevant feedback tests; add
compact data parity assertions only if current coverage leaves this translation
unprotected. Run routed BattleFeature checks and app compilation.

Inspect shipping motion for normal/critical/blocked hits, Dodge, Heal, celebration,
party/enemy lunges, interruptions, and reduced motion. Use recordings or live
inspection; still screenshots do not establish animation parity. Follow the
[visual completion gate](../Platform/Verification.md#visual-completion-gate).
Done means one shared phase duration has one authored value, named phases replace
indices, and celebration retains its independent rotation.

## Complex areas deliberately excluded

- **Cloud sync and save schemas:** the earlier immutable save-action work is
  present in this baseline. `CloudSaveMutation.Replay` already separates actions,
  receipts, economic deltas, and snapshots. Historical records contain different
  information; converting all to current actions could invent facts or change
  replay. Preserve readers, production claims, retired IDs, epochs, and accounts.
- **Journal storage:** `CloudSaveJournalRecords` shares immutable history and bounds
  append copying/tree depth. An array replacement could restore history-sized
  copying. Require workload measurements before changing it.
- **Combat executor:** its unusual executor preserves synchronous calling-thread
  commands while moving deep reaction frames off the native stack.
  `CombatExecutorTests` exercise small-stack continuations and seeded chains. A
  queue rewrite is a separate high-risk project, not an obvious simplification.
- **Battle lifecycle seams:** opaque handles, per-owner installation guards,
  run-bound claims, and presentation snapshots have documented ownership,
  reentrancy, and timing jobs. Repeated-looking state is not evidence that a single
  giant session enum would be better.
- **Raster feedback and artwork preparation:** caches, pins, and publication
  bridges have performance/lifetime contracts. Change them only with evidence of
  equal appearance and frame pacing.
- **Generated catalogs and repository navigation tools:** volume or a single
  caller does not establish excess. This pass found no concrete reason to replace
  generation or remove supported CLI entry points.

## Execution and acceptance checklist

Follow the [standing task workflow](../../AGENTS.md#route-and-read) and
[verification policy](../Platform/Verification.md). The checks below are specific
to this simplification; each finding's verification section defines its behavioral
and visual acceptance criteria.

- [ ] Refresh the selected evidence, applicable guidance, and actual consumers
      against current main; preserve overlapping unfinished work.
- [ ] Record baseline behavior for each consequential migration. Add tests only
      for consequential coverage gaps.
- [ ] Implement one coherent cluster at a time. Delete the replaced path before
      declaring its cluster finished.
- [ ] Complete shipping-UI inspection for motion, cues, and delayed feedback.
      Retain revision-linked artifacts in `.DerivedData/Deliverables/`.
- [ ] Confirm maintenance improvements: retry follows a result; composite meaning
      has one owner; packet meaning is explicit; shared motion timing is authored
      once. Net deletion is desirable but does not substitute for these outcomes.
- [ ] Fold final behavior into canonical docs and delete this plan when completed
      or cancelled. Report local, visual, device, and hosted evidence separately.

Coverage: the production paths above, their relevant regression cases, package
contracts, and selected tooling. This was not an exhaustive review of every
screen, generator, platform adapter, or test. The exclusions reject specific
simplifications; they do not certify those systems as debt-free.
