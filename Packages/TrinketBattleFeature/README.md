# TrinketBattleFeature

Battle lifecycle, presentation, and SwiftUI for Trinket.

## Ownership

- `BattleSession`: production `BattleRuntime`; owns lifecycle, simulation, commands,
  and presentation coordination for one battle
- `BattlePresentationState`: observable combat projection
- `BattleFeedbackLane`: feedback scheduling and bounded raster publication
- `BattleSpectacleState`: skill callouts, cinematics, and outcome timing
- Battle views, layout, effects, and outcome presentation

Battle simulation rules remain in `BattleEngine`. App options and audio enter through
the closure-backed `BattleRuntimeDependencies`; this package must not import or
depend on `TrinketAppState`.

## Testing

```sh
./Scripts/test-package.sh TrinketBattleFeature
./Scripts/test.sh smoke SmokeBattleTests
```

Internal feedback, raster, recipe, and timing tests stay in this package rather than
making those implementation types public.
