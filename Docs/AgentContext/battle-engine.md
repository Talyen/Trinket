# Battle engine context

Load for `Packages/BattleEngine` rules, effects, decks/hands, damage, triggers, or engine tests.

Start with `BattleState`, the matching `EffectHandlers/` type, or the matching `CombatTriggerEngine+*.swift` cadence extension. `BattleState` is a facade: put shared mutation plumbing in `BattleState+*.swift`; place rule branches in handlers or engines. Do not put feature calls in the engine. BattleState shares its immutable modifier profiles through private storage so nested card resolution does not copy those large values into every state snapshot.

Battle state, roster, and combatant storage are externally read-only. Commands and
log lifecycle are the public mutation boundary; handler dispatch and turn/card engine
drivers stay package-scoped. Consumers that inspect future RNG values must copy the
generator rather than advance the live battle's generator.

`BattleRoster` owns participant identity. Combatant reads and runtime writes require
an exact roster ID and matching role; role alone cannot address live battle state.
Modifier lookup uses the same roster ID resolver, without reserved role-name aliases.
Unknown combatants return empty read projections and cannot replace a roster member.
`CombatantRuntime` owns all personal Talent preparations/history and Unique equipment
readiness, counters, and tracked cards. They share its copy-on-write storage, equality,
and hashing with the rest of its rule state; roster copies and updates carry them
with their owner. Do not add parallel actor-ID or participant-keyed state dictionaries
on `BattleState`. `CombatResolution` retains action/card frames and activation claims;
`UniqueBattleState` retains in-flight card work, effect retention, and reaction queues
that span participants. Their existing cadence and reaction ordering remain separate
from runtime storage.

`CombatExecutor` drains each synchronous command on its calling thread. Internal
rules use async continuations; entering damage, healing, or automatic card play
suspends before child resolution so parent state lives on the heap. Await child
rules in their existing order. These continuations must not await I/O, actors,
timers, or independent tasks. Use synchronous facade commands only at command
entry; internal reactions await their async overloads to retain one executor.
Keep existing chain limits and post-damage counterattack/Block-answer timing.
Public card, turn, and opening commands return `BattleCommandResult` only after
resolution completes. `BattleState.nextEvent` writes command output in emission
order, independently of retained battle history and optional action recording.
Card/turn orchestration does not reconstruct command events from child return
values. Damage, healing, and Leech outcomes carry rule facts only; their nested
reactions emit directly into the enclosing command output without copying local
event ranges. Outcome Health and impact facts are immutable; internal result flags
use a compact bitset rather than allocated sets. Internal card plays and enemy/turn-start phases likewise emit
without returning parallel arrays. Explicit test observers use `collectingEvents`
or `collectingResult` at the operation boundary, including when retained battle
history is disabled.
Counterattacks drained after the outer damage packet remain in emission order.
Discarded damage previews detach command output so speculative effects cannot publish.
Internal triggers, effect turns and checkpoints likewise emit directly into this
output rather than returning parallel arrays. Gold and Block grants return their
applied amounts; action admission and DoT dispatch return decisions, independently
of emitted feedback.
Card plays, direct resource grants, and control-meter charges expose committed
rule facts separately from emitted events. Critical-attack continuation, triggered-control
rewards, and direct gain summaries consume those facts, never event searches,
display names, or event positions. Critical card facts include nested attacks from
the same actor but exclude critical healing. The active card frames own those
facts even when history and optional action recording are disabled.
Optional action recording never invokes consumer code or exposes intermediate
engine snapshots.
`EffectHandlers.advanceTurn` selects specialized ticks directly; ordinary timed
effects share the countdown fallback.
`CombatExecutorTests` owns small-stack, ordered-unwind and recorded-battle parity
coverage; package compilation and execution follow the normal CI-owned policy.

On-hit and reaction work is split on purpose:

- `DamagePipeline` orders committed-damage reactions; `AttackerOnHitEngine` owns attacker-side on-hit applications during that checkpoint, including first-hit bonuses and attacker-ward DoTs. Keep live roster checks inside rider execution because earlier reactions can change Health and effects.
- `CombatTriggerEngine` owns post-hit cadence such as after spend mana, after dodge, after cleanse, turn start/end, enemy turn, leech, and party auras.

Do not fold those cadences into the pipeline or merge affix scalar fields on `CombatModifierProfile` with `triggers`; the dual channel is intentional.

`CombatModifierProfile.merge(_ modifier:)` exhaustively applies every `AffixModifier`.
Keep this mapping single-owned and explicit so new modifier cases require a combat
decision at compile time; `AffixModifier.apply(to:)` delegates to it.

Content's `CombatantMaxValues` owns maximum Health/Mana calculations, using shared
saturating arithmetic and combat rounding for extreme inputs. The engine's
`CombatantMaxValues+Effects.swift` adds active Maximum Mana stack totals.
`CombatantRuntime` clamps explicit starting Health and Mana to zero through their
capacity before recording defeat progress. Initial Mana capacity includes active
effects; omitted starting Mana still uses the build's ordinary starting value.
`CombatBuild` exposes the build's maximum values; build resolution, modifier profiles,
and catalog-to-profile adapters live in Content's `Roster/` folder, including
`CombatBuildResolver.swift` and `CombatModifierProfile+Catalogs.swift`.
`CombatModifierProfile.triggerAbilityNames` keys are schema-generated
`CombatTriggerField` values shared with Content's populated-field and affix-roll
metadata. Provenance retains first-writer precedence when profiles merge.
Half-Health checks use `HealthThreshold` to preserve strict odd-number boundaries
without doubling saturated Health or rounding through `Double`.
Status-summary duration formatting uses `Effect.durationTurns` by default; handlers
with selective duration rules supply an extractor.

`EffectApplication` owns immutable effect/ability/source/target attribution and
exhaustively dispatches the closed `Effect` set. Its store and event operations
share that attribution; stored-effect ticks and summaries live in `EffectHandlers`.
The specialized Burn/Poison and Bleed applicators report committed Health damage
or stored status, including lethal immediate hits. The keyword dispatcher instead
reports whether it handled the keyword. Revival returns actual restored Health and
requires a registered roster identity; callers do not infer application from event
IDs or stack counts.
Status-only mutations borrow the roster effect array through `mutateEffects`, or
directly through the participant when RNG is borrowed alongside it. Mana capacity
and reaction expiry synchronize once at the end of each borrow.
Replacement removes and inserts within one borrow, so those checks see the complete
replacement. Block consumption, Talent point drains, and accelerated expiry compact
surviving stacks in place; callers retain rule facts rather than replacement arrays.
Stored buffs share replacement and feedback while retaining their stacking rules.
Thorns and Kindled share saturating amount-buff operations. Block grants use
`BattleState.applyBlockGain`; all other insertion uses `insertEffect`.
For a new effect kind, add its application dispatch case and any specialized lifecycle rules. Existing handler and turn-processing
coverage may suffice; add or extend `EffectHandlersApplyTests` only when a behavior
gap meets the [Testing.md](../Platform/Testing.md) value threshold. Use a thin
integration case only when the existing owner cannot prove the interaction and
the same threshold passes. Testing.md also owns retirement, fixtures, seeds, and
dispatch conventions.

`CombatCheckpoint` checks eligibility before each ordered reaction. Prepared-action
and card-completion work requires a living actor; winning cards can finish support
rewards. Enemy action delays precede preparation, while attack-only interception
uses the selected outcome and rechecks control after reactions. Recovery rewards
require the final skipped action to finish. Committed damage consequences retain
their own source/target rules, including periodic damage from defeated sources.
Health-loss Mana and card-draw rewards wait for Death's Door or another lethal
protection to restore their owner; a final defeat grants neither reward.

`BattleRoster.hasAffliction` distinguishes
active debuffs from keyword-associated buffs for conditions and damage rules.

## Focused contracts

Use `agent-context.sh` to locate applicable contracts; follow calls into other
concerns as needed. Shared or unrecognized engine paths list all three operation
references for discovery, not as unconditional whole-document prereads. Known
damage, Block/defense, and Dodge trigger files route to the damage contract.
`BattleTurnEngine` owns action orchestration; its `+Resolution` extension owns
damage components and targeted effects without changing operation order.

| Concern | Canonical contract |
|---|---|
| Damage, reactions, effect application and expiry | [Damage and effects](battle-damage.md) |
| Card/action identity, hand, Mana and preparations | [Actions and cards](battle-actions.md) |
| Healing allocation, gains and party auras | [Healing and gains](battle-healing.md) |
| Named talent behavior | [Talent interactions](battle-talents.md) — look up the changed talent |
| Scaling, pacing, sweep evidence | [Balance](battle-balance.md) |
