# Battle context

Use for card rules, effects, decks/hands, turn flow, and battle presentation.

| Concern | Owner / entry point |
|---|---|
| Domain primitives | `Packages/TrinketCore` |
| Authored combatants, abilities, stages | `Packages/TrinketContent` and `ContentManifest/` |
| Rules, effect handlers, deck/hand | `Packages/BattleEngine` |
| App launch/victory orchestration | `Trinket/BattleShell/`, `Trinket/State/BattleSession` |
| Battle SwiftUI | `Trinket/Features/Battle/` |

Start with `BattleState`, the matching `EffectHandlers/` type, and the closest test in `Packages/BattleEngine/Tests/`. `BattleState` is a facade: add shared mutation plumbing in `BattleState+*.swift`; place rule branches in handlers or engines. Do not put feature calls in the engine.

For a new effect kind, update registry parity and `EffectHandlersApplyTests`; use a thin integration test only for multi-effect interactions. Use `BattleStateTestFactory.makeBattle(..., rngSeed: 0)` and `EffectHandlers.all`. Do not assert full log prose.

Run `./Scripts/test.sh style` and `./Scripts/test-package.sh BattleEngine`. For UI-only battle changes, also run `./Scripts/test.sh smoke`. Read `Packages/BattleEngine/Tests/README.md` for the ownership matrix and `Docs/Plans/BattleCardCombatMigration.md` only for migration work.

Headless balance sweeps (non-user-facing): `Docs/Plans/BattleBalanceSimulator.md` and `./Scripts/balance-sweep.sh`.
