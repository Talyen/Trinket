# Battle engine context

Load for `Packages/BattleEngine` rules, effects, decks/hands, damage, triggers, or engine tests.

Start with `BattleState`, the matching `EffectHandlers/` type, or the matching `CombatTriggerEngine+*.swift` cadence extension. `BattleState` is a facade: put shared mutation plumbing in `BattleState+*.swift`; place rule branches in handlers or engines. Do not put feature calls in the engine. BattleState shares its immutable modifier profiles through private storage so nested card resolution does not copy those large values into every state snapshot.

Battle state, roster, and combatant storage are externally read-only. Commands and
log lifecycle are the public mutation boundary; handler dispatch and turn/card engine
drivers stay package-scoped. Consumers that inspect future RNG values must copy the
generator rather than advance the live battle's generator.

On-hit and reaction work is split on purpose:

- `DamagePipeline` applies talent on-hit applications during damage resolution, including first-hit bonuses and attacker-ward DoTs.
- `CombatTriggerEngine` owns post-hit cadence such as after spend mana, after dodge, after cleanse, turn start/end, enemy turn, leech, and party auras.

Do not fold those cadences into the pipeline or merge affix scalar fields on `CombatModifierProfile` with `triggers`; the dual channel is intentional.

For a new effect kind, maintain registry parity. Existing handler and turn-processing
coverage may suffice; add or extend `EffectHandlersApplyTests` only for a consequential
behavior gap. Use a thin integration case when a meaningful interaction cannot be
proved by the existing owner. Apply [Testing.md](../Platform/Testing.md) for value,
retirement, fixtures, seeds, and dispatch conventions.

`CombatCheckpoint` checks eligibility before each ordered reaction. Prepared-action
and card-completion work requires a living actor; winning cards can finish support
rewards. Enemy action delays precede preparation, while attack-only interception
uses the selected outcome and rechecks control after reactions. Recovery rewards
require the final skipped action to finish. Committed damage consequences retain
their own source/target rules, including periodic damage from defeated sources.

`BattleRoster.hasAffliction` distinguishes
active debuffs from keyword-associated buffs for conditions and damage rules.

## Focused contracts

Read the contracts selected by `agent-context.sh`; when following a call into a
new concern, load that contract too. Shared or unrecognized engine paths route
all three operation contracts so an ambiguous owner cannot silently omit rules.

| Concern | Canonical contract |
|---|---|
| Damage, reactions, effect application and expiry | [Damage and effects](battle-damage.md) |
| Card/action identity, hand, Mana and preparations | [Actions and cards](battle-actions.md) |
| Healing allocation, gains and party auras | [Healing and gains](battle-healing.md) |
| Named talent behavior | [Talent interactions](battle-talents.md) — look up the changed talent |
| Scaling, pacing, sweep evidence | [Balance](battle-balance.md) |
