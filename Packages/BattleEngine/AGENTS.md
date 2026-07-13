# BattleEngine-local guide

Read `Docs/AgentContext/battle.md` before editing. Keep combat rules, effect handling, deck/hand logic, and turn mutation in this package; never import the app or feature views.

Use deterministic `BattleStateTestFactory` setup and cover changed rules in `BattleEngineTests`. The root task-scoped workflow selects style and package checks; for a deliberately narrow iteration, run `./Scripts/test-package.sh BattleEngine`.
