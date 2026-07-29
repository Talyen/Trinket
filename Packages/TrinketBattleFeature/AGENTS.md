# TrinketBattleFeature-local guide

Keep rules in `BattleEngine`. `BattleSession` is the lifecycle/command facade; place
display state in the existing presentation, feedback, or spectacle lane and have
views observe the narrowest lane. App options/audio cross only through
`BattlePresentationEnvironment`. Never import `TrinketAppState` or the app module.

BattleFeature must not branch on play-mode identity (journey / spire / labyrinth).
Receive opaque `BattleRunKey` and presentation fields baked at launch
(`defeatPrimaryAction`, `hasProgressionRewards`, `musicStageID`, XP/material awards).
`ActiveBattleConfiguration` is a pure DTO — do not assemble from live roster,
inventory, or homestead, and do not call `StageCompletion` reward math here.
Victory chrome uses those baked awards — do not re-derive `StageCompletion` policy in
outcome math.

Run the package suite and routed Battle smoke/performance checks before handoff.
