# TrinketBattleFeature-local guide

Keep rules in `BattleEngine`. `BattleSession` is the lifecycle/command facade; place
display state in the existing presentation, feedback, or spectacle lane and have
views observe the narrowest lane. App options/audio cross only through
`BattlePresentationEnvironment`. Never import `TrinketAppState` or the app module.

Run the package suite and routed Battle smoke/performance checks before handoff.
