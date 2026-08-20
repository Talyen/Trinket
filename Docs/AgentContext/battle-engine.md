# Battle engine context

Load for `Packages/BattleEngine` rules, effects, decks/hands, damage, triggers, or engine tests.

Start with `BattleState`, the matching `EffectHandlers/` type, or `CombatTriggerEngine` (`CombatTriggerEngine+*.swift` by cadence: damage, defense, mana, card play, enemy turn, turn start/end, cleanse including post-cleanse heal/draw, resources, holy, leech, and party auras). `BattleState` is a facade: put shared mutation plumbing in `BattleState+*.swift`; place rule branches in handlers or engines. Do not put feature calls in the engine.

On-hit and reaction work is split on purpose:

- `DamagePipeline` applies talent on-hit applications during damage resolution, including first-hit bonuses and attacker-ward DoTs.
- `CombatTriggerEngine` owns post-hit cadence such as after spend mana, after dodge, after cleanse, turn start/end, enemy turn, leech, and party auras.

Do not fold those cadences into the pipeline or merge affix scalar fields on `CombatModifierProfile` with `triggers`; the dual channel is intentional.

For a new effect kind, update registry parity and `EffectHandlersApplyTests`; use a thin integration test only for multi-effect interactions. Use `BattleStateTestFactory.makeBattle(...)` with the factory default deterministic seed (`CombatantFixtures.deterministicBattleSeed`, currently `1772`); use explicit seeds only for RNG edge-case tests. Dispatch via `EffectHandlers.all` and assert event semantics rather than full log prose.

Keep balance/scaling details in [battle-balance.md](battle-balance.md). Handoff routes engine changes through the `BattleEngine` package suite.
