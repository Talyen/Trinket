# Battle engine context

Load for `Packages/BattleEngine` rules, effects, decks/hands, damage, triggers, or engine tests.

Start with `BattleState`, the matching `EffectHandlers/` type, or the matching `CombatTriggerEngine+*.swift` cadence extension. `BattleState` is a facade: put shared mutation plumbing in `BattleState+*.swift`; place rule branches in handlers or engines. Do not put feature calls in the engine. BattleState shares its immutable modifier profiles through private storage so nested card resolution does not copy those large values into every state snapshot.

On-hit and reaction work is split on purpose:

- `DamagePipeline` applies talent on-hit applications during damage resolution, including first-hit bonuses and attacker-ward DoTs.
- `CombatTriggerEngine` owns post-hit cadence such as after spend mana, after dodge, after cleanse, turn start/end, enemy turn, leech, and party auras.

Do not fold those cadences into the pipeline or merge affix scalar fields on `CombatModifierProfile` with `triggers`; the dual channel is intentional.

For a new effect kind, update registry parity and `EffectHandlersApplyTests`; use a thin integration test only for multi-effect interactions. Test conventions (fixtures, seeds, dispatch) live in `Docs/Platform/Testing.md`.

Keep balance/scaling details in [battle-balance.md](battle-balance.md).
