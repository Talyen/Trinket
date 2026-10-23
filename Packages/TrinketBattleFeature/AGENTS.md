# TrinketBattleFeature-local guide

Keep rules in `BattleEngine`. Never import `TrinketAppState` or the app module.
App options/audio cross only through `BattlePresentationDependencies`. Conform to
the [common runtime contract](../../Docs/AgentContext/battle-runtime.md) and the
linked launch and presentation contracts; read the sections for the changed behavior.

Package and interaction verification follow
[Verification.md](../../Docs/Platform/Verification.md#choosing-ui-verification);
performance work follows the linked playbook.
