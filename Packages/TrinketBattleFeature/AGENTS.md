# TrinketBattleFeature-local guide

Keep rules in `BattleEngine`. `BattleSession` is the production `BattleRuntime` and
owns battle lifecycle, simulation, and presentation coordination. Place display
state in the existing presentation, feedback, or spectacle lane and have views
observe the narrowest lane. App options/audio cross only through
`BattleRuntimeDependencies`. Never import `TrinketAppState` or the app module.

BattleFeature follows the shared launch/DTO ownership contract in
[`Docs/AgentContext/battle.md`](../../Docs/AgentContext/battle.md): it receives
pre-resolved inputs, does not branch on play-mode identity or assemble from live save
slices, and does not re-derive Persistence reward policy in outcome math.

Run the package suite and routed Battle smoke/performance checks before handoff.
