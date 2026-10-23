---
type: execution-plan
status: active
created: 2026-10-23
updated: 2026-10-23
expires: 2026-11-06
---

# Codebase simplification proposal

## Assessment and scope

The largest avoidable complexity is in economic save mutations and cloud replay.
A single player action currently has several representations whose agreement is
maintained procedurally. Combat damage is the next most difficult area to reason
about: a large mutable packet carries calculation scratch, committed results, and
reaction bookkeeping through many ordered helpers. Battle lifecycle transitions
and verification routing offer smaller, more bounded simplifications.

The user approved all five workstreams on 2026-10-23, including reuse of existing
save-action work, behavior preservation, stage verification, and local integration.
Preserve gameplay, save compatibility, UI, package dependencies, and verification
policy unless a separate product decision explicitly changes them.

## Execution progress

- [x] Review and reuse the existing save-action migration (`e0660f96d`).
- [x] Verify local action authority and explicit cloud replay ownership: AppState
  218 passed / 1 skipped, Persistence 413 passed, static checks and app compilation passed.
- [ ] Narrow damage calculation and committed reaction inputs with trace parity.
- [ ] Encode battle transition state and verify reentry and replacement flows.
- [ ] Share verification facts and matching semantics with selection parity.
- [ ] Run whole-task verification, review, close the plan, and integrate locally.

The inspection baseline is committed local main `b7bdef743`. Evidence below comes
from source, callers, behavior contracts, existing tests, and relevant Git history.
Tests were inspected for their assertions; they were not executed as part of this
architectural investigation. These findings establish maintenance costs, not newly
reproduced player bugs or measured performance regressions. File counts and line
counts identify the scope inspected, not proof that code should be deleted.

| Priority | Workstream | Evidence and confidence | Expected benefit | Migration risk |
| --- | --- | --- | --- | --- |
| 1 | One authority for economic save actions | High: candidate mutation and receipt construction are separate operations | Remove duplicate accounting work from every save command | High: save/retry/claim compatibility |
| 2 | Separate modern cloud replay from historical reconciliation | High: replay selects among receipts, economic actions, and snapshot inference, with overlapping field ownership | Make each field's writer and each format's semantics explicit | High: cross-device correctness |
| 3 | Give damage calculation and committed reactions narrower inputs | High complexity confirmed; exact reduction needs a pilot | Reduce temporal coupling and accidental use of unfinished facts | High: ordering, RNG, nested reactions |
| 4 | Replace parallel transition flags with explicit lifecycle states | High: duplicated transition-plus-Boolean representation in two owners | Reduce representable invalid states and repeated teardown branching | Medium: synchronous observation reentry |
| 5 | Share verification ownership facts and matching semantics | High duplication confirmed; consolidation scope is deliberately small | Reduce places updated when paths, packages, or build inputs change | Medium: accidentally skipping checks |

Workstreams 1 and 2 are two halves of one save migration and should share a design
review. They are listed separately because local admission and remote replay have
different correctness and compatibility obligations. Do them before attempting a
broad cleanup of combat.

## 1. Resolve each economic save action once

### Evidence

- [SaveEconomicMutation](../../Packages/TrinketPersistence/Sources/TrinketPersistence/SaveEconomicMutation.swift)
  owns a mutable `save` and an independently appended `receipts` array. Its
  `validate` method replays receipt effects into another save and compares Gold,
  materials, reward remainders, and earned Experience to check agreement.
- [Transaction helpers](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore+Transaction.swift)
  pass both `inout PlayerSave` and a receipt-recording callback into commands.
  Each command must perform two coordinated jobs correctly.
- [Homestead commands](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore+Homestead.swift)
  demonstrate the duplication. `HomesteadBuildMutation.apply` applies the Content
  build operation, then walks `tier.cost` again to construct economic effects.
  Collection separately mutates pending production and Gold, then constructs the
  receipt from the returned amounts and an earlier production snapshot.
- [SaveEconomicReceipt](../../Packages/TrinketPersistence/Sources/TrinketPersistence/SaveEconomicReceipt.swift)
  and [CloudEconomicAction](../../Packages/TrinketPersistence/Sources/TrinketPersistence/Cloud/CloudEconomicAction.swift)
  contain separate economic application paths, including fractional reward carry.
  Their guards and clamping are not textually identical; equivalence cannot be
  assumed merely because the operations have similar names.

The validation is valuable protection. The avoidable part is requiring commands
to author both the change and its accounting, then reconstructing their agreement.

### Target design

Keep ownership in Persistence. Content continues to resolve prices, reward values,
item rolls, and other value-only rules. Persistence resolves one immutable action
at the command's existing admission boundary, retaining its actual before/after
values, semantic kind, and claim identity. The candidate save and its receipt are
derived from that resolved action. A batch contains ordered child actions so that
independent payouts keep independent identities.

Use the existing transaction and journal machinery. Add no command bus, public
mutation protocol, plugin registry, or event-sourced replacement for `PlayerSave`.
The resolved action should be internal unless a current consumer proves otherwise.

### Implementation sequence

1. Review existing commit `e0660f96d` (`refactor: resolve committed save actions
   once`) before writing replacement code. The object exists locally and is not
   an ancestor of the inspected baseline. Its changed files already include
   `ResolvedSaveAction`, save commands, journal encoding, and cloud replay. Treat
   it as a migration candidate, not as reviewed or currently verified work.
2. Compare that commit against current Content and Persistence contracts and all
   intervening main changes. Reuse understood parts in the task worktree; preserve
   unrelated branch work. Do not blindly land or duplicate the old implementation.
3. Pilot one Homestead upgrade and one battle reward. Resolve values once; derive
   accounting from the retained result. Keep receipt validation at commit as an
   independent rejection gate rather than deleting it to obtain a smaller diff.
4. Migrate collection, Shop purchase, Salvage, forge, and Mystery/completion paths.
   Retain production positions, pinned item/price values, saturation, and refund
   semantics. Snapshot the smallest sufficient value; measure before retaining
   full saves at every child action in a large batch.
5. Replace the dual mutation/receipt callback API only after its callers migrate.
   Remove superseded constructors and duplicate arithmetic where historical
   readers do not require the old behavior. Keep historical readers isolated.

### Verification and completion

Use existing economic-action, journal, receipt-sync, merge-claim, and encounter
tests as the starting inventory. Confirm actual assertions for reload survival,
failed write followed by retry, multiple child payouts, duplicate claims, capped
Gold, fractional carry, production collection, retired items, and pinned Shop
stock. Add coverage only for a consequential gap discovered during migration.

Completion means gameplay commands no longer independently construct their wallet
changes and economic receipts. Receipt validation still rejects incomplete
coverage before publication, failed writes publish neither representation, and
current Content values cannot alter replay of already committed actions.

## 2. Give cloud replay one economic writer per format

### Evidence

- [CloudSaveReconciler.replay](../../Packages/TrinketPersistence/Sources/TrinketPersistence/Cloud/CloudSaveReconciler.swift)
  restores before/after snapshots, calls `CloudSaveMerge.merge`, then chooses
  receipt replay or historical `economy.replay`. Snapshot-only history takes
  another path through merge inference.
- [CloudSaveMerge](../../Packages/TrinketPersistence/Sources/TrinketPersistence/Cloud/CloudSaveMerge.swift)
  accepts `reconcileEconomy: Bool`. That Boolean also changes the meaning of
  `Branches.canCombineIndependentRewards`, which is consumed by roster Experience
  merging as well as economic merging.
- [CloudReceiptReplay.apply](../../Packages/TrinketPersistence/Sources/TrinketPersistence/Cloud/CloudReceiptReplay.swift)
  restores Gold, material balances, remainders, and selected Experience progressions
  from `existing`, then replays receipts. This makes intermediate field ownership
  important to understanding the final result.
- [Snapshot economy reconciliation](../../Packages/TrinketPersistence/Sources/TrinketPersistence/Cloud/CloudSaveMerge+Economy.swift)
  infers overlapping production, shared upgrades, and fractional rewards. These
  rules are necessary for historical evidence that lacks explicit actions; they
  should not remain an implicit part of the modern action path.
- [CloudSaveJournal](../../Packages/TrinketPersistence/Sources/TrinketPersistence/Cloud/CloudSaveJournal.swift)
  retains optional `economy` and `receipts`, snapshot deltas, and collection
  positions, and reads historical array encodings. Simply deleting old paths
  would break readers and saved outboxes.

### Target design

Select the replay semantics once at the compatibility boundary. A small internal
enum can distinguish action-backed history, receipt-backed history, historical
economic deltas, and snapshot-only history. Preserve the difference between absent
receipts and an explicitly empty receipt set. Some historical entries lack enough
information to become modern actions; retain their original semantics explicitly.

For modern action-backed history, merge structural progress separately and replay
economics exactly once. Name the field ownership clearly: inventory and equipment,
completion markers, Gold/materials, Experience, production credit, and remainders.
Experience belongs in the economic ownership review even though it is stored in
the roster. Production settlement and structural claim markers must use the same
accepted/duplicate decision as the economic award.

### Implementation sequence

1. With workstream 1, write a field-ownership table against current replay and
   merge functions. Check the earlier commit for an existing solution first.
2. Introduce explicit decoded replay variants without changing historical wire
   tags, identifier meanings, or error behavior. Reject unsupported versions.
3. Separate the action-backed structural merge entry point from historical
   snapshot reconciliation. Replace the generic Boolean switch where this removes
   ambiguity; retain shared pure merge helpers where their semantics are identical.
4. Compute each action's duplicate/accepted decision once and apply it consistently
   to economics and structural effects. Keep production interval claims and item
   retirement state; they solve concrete cross-device conflicts.
5. Remove modern-path economic overwrite-and-replay work that the ownership split
   makes redundant. Keep legacy inference behind the historical variant. Do not
   remove a reader until its consumer window is proven closed or a break approved.

### Verification and completion

Use the existing Cloud journal, receipt-sync, economic-action, and merge regression
suites. Exercise both device orderings and repeated delivery for independent
rewards, duplicate completion claims, purchase then Salvage, concurrent upgrades,
overlapping collection intervals, and mixed old/new history. Include account/reset
epochs, unsupported formats, outbox acknowledgement, and restored-save validation.

Completion means the modern replay path has one writer for each economic field
and a visible decision about each claim. Historical reconstruction is still
available but is no longer interleaved with the modern algorithm. A smaller number
of files is not required; fewer overlapping authorities is the intended outcome.

## 3. Narrow the damage pipeline's mutable contract

### Evidence

The inspected `Damage/` directory contains 17 Swift files and 4,354 lines.
Its size partly reflects real game rules; the concern is its shared working state:

- [DamageResolutionState](../../Packages/BattleEngine/Sources/BattleEngine/Damage/DamageResolutionState.swift)
  mixes immutable request inputs, outgoing/defense scratch, hit-time status,
  committed Health loss, and reaction flags in one value passed as `inout`.
- [DamagePipeline.run](../../Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipeline.swift)
  initializes facts at particular stages, has separate elemental and Health-cost
  paths, then executes a long, explicitly ordered reaction sequence. Helpers can
  access fields that are meaningful only after some earlier helper has run.
- [Health commitment](../../Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipelineResolutionSteps+TakeDamage.swift)
  also launches defender reactions. [Block absorption](../../Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipelineResolutionSteps+Shield.swift)
  commits one pool before its reactions, then reads the next pool live. A clean
  looking global calculation/commit/reaction split would change this behavior.
- [DamageOperation](../../Packages/BattleEngine/Sources/BattleEngine/Damage/DamageOperation.swift)
  already provides named operation kinds, and [CombatExecutor](../../Packages/BattleEngine/Sources/BattleEngine/Actions/CombatExecutor.swift)
  already solves deep continuation stack safety. Replacing either wholesale is
  unnecessary for this simplification.

### Target design

Keep the existing linear orchestration and live checkpoints. Separate stable
request inputs and hit-time observations from scratch that changes during
calculation. Where a helper only reads the result of a committed defense/Health
operation, give it a narrow result value instead of the entire mutable packet.
Keep genuinely evolving reaction bookkeeping mutable with its actual owner.

Do not make all combat facts immutable at the beginning of an action. Hit-time
status and live continuation eligibility are different facts. Nested damage,
borrowed Block, Death's Door, DoT mirrors, Leech, and control reactions must retain
the exact existing observation points and event order.

### Implementation sequence

1. Inventory the readers/writers of `remaining`, `healthLost`, `targetStatus`,
   `blockedAmount`, `isCritical`, and the pending/Unique fields. Record the actual
   moment each becomes valid. Use this inventory to choose the first seam.
2. Pilot a private or package-scoped committed-hit value at the existing
   `applyTakeDamage` result boundary. Move only read-only consumers first. Preserve
   reactions currently inside that function and the shield pool function.
3. Separate calculation scratch only where this eliminates default-initialized
   fields or broad helper access. Do not introduce a type per pipeline step.
4. Reuse existing nested-damage and reward emitters; remove helpers whose only job
   became copying or forwarding the same state. Preserve attacker on-hit versus
   post-hit cadence ownership from the package contract.
5. Expand beyond the pilot only if the changed call sites are easier to read and
   the mutable surface is measurably narrower. If the result merely relocates
   fields behind wrappers, stop and retain the smaller improvement.

### Verification and completion

Start with existing `CombatExecutorTests`, `DamageCadenceRegressionTests`, resolved
damage tests, card boundary tests, Block/defense regressions, and Unique damage
tests. Compare deterministic command traces before/after: ordered events,
resolved actions, combatant changes, final roster/effects, hand/deck state, Gold,
and subsequent seeded behavior. A final-Health-only comparison is insufficient.

Include dodges with Winter's Wake, borrowed Block breaking, fatal interception,
Death's Door, counterattacks, repeated cards, capped damage, and DoT/Leech chains.
Keep the executor's small-stack tests. Inspect representative shipping battle
flows if event delivery or its presentation boundary changes; compilation alone
does not establish unchanged sound, animation, and interaction timing.

Completion means read-only reaction helpers cannot accidentally mutate calculation
scratch, the order remains visible in one orchestration path, and all migrated
tests retain their assertions. No new pipeline framework or rule interpreter.

## 4. Encode battle transition state directly

### Evidence

Both [PlayBattleCoordinator](../../Packages/TrinketAppState/Sources/TrinketAppState/Play/PlayBattleCoordinator.swift)
and [BattleSession](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/BattleSession.swift)
store an optional `RuntimeTransition` plus a separate
`endRequestedDuringInstallation` Boolean. Their respective
[application installation](../../Packages/TrinketAppState/Sources/TrinketAppState/Play/PlayBattleCoordinator+Runs.swift)
and [runtime installation](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/BattleSession+Runtime.swift)
functions manually coordinate admission, deferred exit, teardown, and publication.

The two owners have different responsibilities and must remain separate. The
avoidable complexity is that each represents a deferred end request independently
of the installing phase in which it is meaningful. This permits combinations
that callers must rule out procedurally. No failing combination was reproduced.

### Implementation sequence

1. In each owner, replace the pair with a local enum such as `idle`,
   `installing(endRequested: Bool)`, and `ending`. Keep it private/internal and use
   ordinary switches; no shared lifecycle protocol or dependency inversion layer.
2. Route end requests and transition completion through that owner's existing
   installation/retirement functions. Make consume-before-notify ordering explicit.
3. Preserve registration identity, claim state, preparation handles, and display
   identity checks. Those represent distinct lifetimes, not duplicate state.
4. Review every early return and synchronous callback for exactly one teardown and
   complete restoration of the local transition state. Remove the old Boolean
   and checks that are now impossible rather than retaining two representations.

Use existing `BattleCompletionLifetimeTests`, `BattleSessionAppLifecycleTests`,
prepared-reuse tests, and simulation replacement tests. Their cases include reset
during installation, reentrant exit, stale finish callbacks, and replacement runs.
Verify the shipping Retry/Leave/Collect/background flows if lifecycle changes
affect observable presentation. Completion means illegal phase/flag combinations
are unrepresentable without changing the two owners' boundary or feedback timing.

## 5. Reduce duplicated verification-routing facts

### Evidence

- [build-inputs.env](../../Scripts/build-inputs.env) lists test packages and
  generation inputs; [change_routing.py](../../Scripts/internal/change_routing.py)
  uses these for local scope and has additional path and consumer rules.
- [ci-path-filter.py](../../Scripts/ci-path-filter.py) separately enumerates
  `SHARDS`, code/smoke path patterns, reviewed manifest hashes, dependency
  propagation, and a component-aware glob matcher.
- The local matcher uses `fnmatchcase` on a whole path while the CI matcher handles
  path components and `**` explicitly. Their different wildcard meanings are
  confirmed implementation facts; this inspection did not establish an incorrect
  skipped gate. Local bounded checks and hosted qualification intentionally select
  different work and must continue doing so.

### Implementation sequence

1. Separate shared facts from policy: package identity, generated ownership,
   generation inputs, and well-defined matching operations are candidates for
   reuse. Local check budgets, CI shards, hosted qualification, and trust checks
   remain with their current callers.
2. Reuse the existing input and generated-path registries. Validate that shard
   membership covers the package inventory exactly once. Add a new registry only
   if existing owners cannot express a shared fact without ambiguity.
3. Put path matching in one small pure helper if both callers can use explicit
   semantics. First characterize old pattern results, including root files,
   nested files, `*` versus `**`, renames, deletions, and unknown inputs. Convert
   patterns deliberately; do not change matcher semantics with a mechanical import.
4. Retain reviewed-manifest/trust checks and conservative fallbacks for truncated
   comparisons, history rewrites, unknown layouts, and unavailable dependency
   evidence. Move code only where it deletes a second implementation.
5. Preserve every existing CLI and documented local/hosted distinction. Do not
   create a general workflow engine or force local checks to execute hosted scope.

Use [CI path filter tests](../../Scripts/Tests/test_ci_path_filter.py) and
[handoff routing tests](../../Scripts/Tests/test_ci_handoff_routing.py), including
matrix conservation, unchanged downstream consumers, and full-scope fallback.
Compare before/after selected checks on representative scopes. Any reduced hosted
selection must have a reason grounded in the same ownership evidence. Completion
means a fact has one owner, with distinct local/hosted policies still visible.

## Areas deliberately excluded from a broad rewrite

- **Trigger catalog and code generation.** The 14 authored trigger-family JSON
  files contain 914 unique fields, and engine `Triggers/` has 17 files/4,930 lines.
  This deserves focused readability work, but most fields have literal authored
  Swift consumers; volume alone does not prove redundant behavior. The generated
  trigger model already has family grouping and copy-on-write storage. Replacing
  it with another generic rule DSL, reflective dispatch, or hundreds of small
  protocol implementations would add a second engine. Consider only a bounded
  family cleanup after the damage pilot establishes a concrete repeated pattern.
- **Custom combat executor.** Existing small-stack and nested-action tests explain
  its unusual implementation. Replacing it with direct recursion or ordinary
  asynchronous scheduling needs independent proof of stack, ordering, thread,
  and synchronous API parity.
- **Battle raster feedback, narrow observation, and prepared artwork.** They carry
  explicit rendering, publication, and first-screen guarantees. A source-only
  inspection does not justify removing caches, projections, pins, or measured
  UIKit feedback infrastructure. Require rendered and performance evidence.
- **Package splits, origin enums, and historical codecs.** Different navigation,
  completion, identity, and storage types are not automatically duplicates.
  Respect the [deferred seams](../../.agents/knowledge/patterns/architecture-deferred-seams.md).
  Do not merge packages or erase historical meanings to reduce file count.

## Delivery sequence and acceptance

| Stage | Deliverable | Exit condition |
| --- | --- | --- |
| 0 | Review the existing save-action commit and current consumer contracts | Reusable work identified; differences from current main understood |
| 1 | Local action authority plus matching modern cloud replay (1 and 2) | Commands/replay share committed facts; historical behavior preserved; reload/retry/merge evidence passes |
| 2 | Damage boundary pilot, then only justified extensions (3) | Deterministic trace parity and narrower mutation access |
| 3 | Local transition-state simplification (4) | Existing reentry/replacement cases pass and player flows retain timing |
| 4 | Shared routing facts/matching, without policy unification (5) | Selection parity, conservative fallbacks, and existing CLI behavior pass |

Each stage should be independently reviewable and locally landable. Do not combine
the combat and cloud migrations into one large commit. Stage 3 or 4 can be selected
independently if a smaller first change is desired; they are lower-impact than the
save migration. Calendar estimates and guaranteed line-count savings are omitted
because the existing unlanded migration and parity work determine the actual scope.

For every selected stage:

1. Recheck current committed main and the stage's contracts; use an isolated task
   worktree and the scoped briefing before editing. Preserve unrelated changes.
2. Start from existing assertions. Add only consequential missing cases under the
   [coverage decision](../Platform/Testing.md#coverage-decision-new-and-changed-behavior).
   Keep behavior checks independent of the new representation.
3. Run `./Scripts/handoff.sh --quiet` for the full stage. Review selected checks and
   exact executed results; do not treat static checks as compilation or tests.
   Public/package API changes also require unchanged consumer compilation.
4. Inspect final shipping UI where lifecycle, feedback delivery, layout, artwork,
   motion, or copy changes under the [visual gate](../Platform/Verification.md#visual-completion-gate).
   Preserve localization whenever player-facing copy is touched.
5. Review the complete diff for deleted duplicate paths, ownership, save readers
   and writers, and hidden behavior changes. Report authored code removed/added,
   independently maintained facts eliminated, and any remaining duplicate path.
6. Commit and integrate with the shared lock after combined-main review and
   required verification. Push and hosted follow-up require separate authorization.
   Report local, rendered/device, and hosted evidence separately. Fold durable
   rules into canonical owners and delete this plan when its selected work is
   completed or the remainder is cancelled.

Success is fewer places a maintainer must change for one rule, fewer invalid states
to defend against, and equivalent player behavior with preserved saved progress.
Moving the same complexity behind new facades does not satisfy this plan.
