# TrinketBattleFeature-local guide

Keep rules in `BattleEngine`. Never import `TrinketAppState` or the app module.
App options/audio cross only through `BattleRuntimeDependencies`. Conform to
the [common runtime contract](../../Docs/AgentContext/battle-runtime.md) and the
focused contracts selected by the router; load another only when crossing its concern.

Package and interaction verification follow
[Verification.md](../../Docs/Platform/Verification.md#choosing-ui-verification);
performance work follows the linked playbook.
