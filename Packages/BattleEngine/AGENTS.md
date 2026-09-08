# BattleEngine-local guide

Combat behavior must conform to the [battle engine guide](../../Docs/AgentContext/battle-engine.md). Keep combat rules, effect handling, deck/hand logic, and turn mutation in this package; never import the app or feature views.

Consequential combat rules need deterministic evidence in `BattleEngineTests`;
existing coverage may suffice. Apply [Testing.md](../../Docs/Platform/Testing.md)
to additions and retirement; regressions should fail on the old behavior.
