# BattleEngine-local guide

Read `Docs/AgentContext/battle.md` before editing. Keep combat rules, effect handling, deck/hand logic, and turn mutation in this package; never import the app or feature views.

Use deterministic `BattleStateTestFactory` setup and cover changed rules in `BattleEngineTests`. Run `./Scripts/test.sh style` and `./Scripts/test-package.sh BattleEngine`.
