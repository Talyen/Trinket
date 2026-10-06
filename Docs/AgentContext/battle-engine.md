# Battle engine context

Load for `Packages/BattleEngine` rules, effects, decks/hands, damage, triggers, or engine tests.

Start with `BattleState`, the matching `EffectHandlers/` type, or the matching `CombatTriggerEngine+*.swift` cadence extension. `BattleState` is a facade: put shared mutation plumbing in `BattleState+*.swift`; place rule branches in handlers or engines. Do not put feature calls in the engine. BattleState shares its immutable modifier profiles through private storage so nested card resolution does not copy those large values into every state snapshot.

Battle state, roster, and combatant storage are externally read-only. Commands and
log lifecycle are the public mutation boundary; handler dispatch and turn/card engine
drivers stay package-scoped. Consumers that inspect future RNG values must copy the
generator rather than advance the live battle's generator.

`CombatExecutor` drains each synchronous command on its calling thread. Internal
rules use async continuations; entering damage, healing, or automatic card play
suspends before child resolution so parent state lives on the heap. Await child
rules in their existing order. These continuations must not await I/O, actors,
timers, or independent tasks. Use synchronous facade commands only at command
entry; internal reactions await their async overloads to retain one executor.
Keep existing chain limits and post-damage counterattack/Block-answer timing.
Default effect-handler witnesses keep async signatures so direct calls cannot
bypass a specialized turn handler.
`CombatExecutorTests` owns small-stack, ordered-unwind and recorded-battle parity
coverage; package compilation and execution follow the normal CI-owned policy.

On-hit and reaction work is split on purpose:

- `DamagePipeline` orders committed-damage reactions; `AttackerOnHitEngine` owns attacker-side on-hit applications during that checkpoint, including first-hit bonuses and attacker-ward DoTs. Keep live roster checks inside rider execution because earlier reactions can change Health and effects.
- `CombatTriggerEngine` owns post-hit cadence such as after spend mana, after dodge, after cleanse, turn start/end, enemy turn, leech, and party auras.

Do not fold those cadences into the pipeline or merge affix scalar fields on `CombatModifierProfile` with `triggers`; the dual channel is intentional.

`CombatModifierProfile.merge(_ modifier:)` exhaustively applies every `AffixModifier`.
Keep this mapping single-owned and explicit so new modifier cases require a combat
decision at compile time; `AffixModifier.apply(to:)` delegates to it.

`CombatantMaxValues` owns maximum Health/Mana calculations, using shared saturating
arithmetic and combat rounding for extreme inputs. `CombatBuild` exposes those
values; content-to-profile adapters live in `CombatModifierProfile+Content.swift`.
Status-summary duration formatting uses `Effect.durationTurns` by default; handlers
with selective duration rules supply an extractor.

`EffectHandlers.handler(for:)` exhaustively selects a handler for every `EffectKind`;
there is no optional registration or missing-handler recovery. Handlers implement
behavior without declaring a second kind. Shared next-hit flag, Cleanse/Purge and resource-to-Block
handlers select their operation from the incoming effect rather than a configured mode.
For a new effect kind, add its dispatch case. Existing handler and turn-processing
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
