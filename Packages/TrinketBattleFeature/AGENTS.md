# TrinketBattleFeature-local guide

Keep rules in `BattleEngine`. Never import `TrinketAppState` or the app module.
App options/audio cross only through `BattleRuntimeDependencies`. Conform to
[`Docs/AgentContext/battle.md`](../../Docs/AgentContext/battle.md).

Run the package suite and routed Battle smoke/performance checks before handoff.
