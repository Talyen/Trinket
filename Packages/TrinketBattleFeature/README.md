# TrinketBattleFeature

Battle lifecycle, presentation, and SwiftUI for Trinket.

## Ownership

- `BattleSession`: active lifecycle and command facade
- `BattlePresentationState`: observable combat projection
- `BattleFeedbackLane`: feedback scheduling and bounded raster publication
- `BattleSpectacleState`: skill callouts, cinematics, and outcome timing
- Battle configuration, resume/outcome values, views, layout, and effects

Battle simulation rules remain in `BattleEngine`. App options and audio enter through
the closure-backed `BattlePresentationEnvironment`; this package must not import or
depend on `TrinketAppState`.

## Testing

```sh
./Scripts/test-package.sh TrinketBattleFeature
./Scripts/test.sh smoke SmokeBattleTests
```

Internal feedback, raster, recipe, and timing tests stay in this package rather than
making those implementation types public.
