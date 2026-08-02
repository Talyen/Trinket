# BattleEngine-local guide

Combat behavior must conform to `Docs/AgentContext/battle.md`. Keep combat rules, effect handling, deck/hand logic, and turn mutation in this package; never import the app or feature views.

Changed combat rules need deterministic tests in `BattleEngineTests` that would fail on the old behavior.
