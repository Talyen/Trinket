# TrinketBattleFeature

Battle lifecycle, presentation, and SwiftUI for Trinket.

## Ownership

- `BattleSession`: production `BattleRuntime`; owns lifecycle, simulation, commands,
  and presentation coordination for one battle
- `BattlePresentationState`: observable combat projection
- `BattleFeedbackLane`: feedback scheduling and bounded raster publication
- `BattleSpectacleState`: cinematics and outcome timing
- Battle views, layout, effects, and outcome presentation
- Ability cards stay **3:4** full-bleed art with no face text. Party portraits stay **3:4**; enemy viewport is **4:3**. Health anchors to the bottom of each combatant’s art. Show mana only when live `maxMana > 0`. No pause control, global crystals, or other top chrome.

Battle simulation rules remain in `BattleEngine`. App options and audio enter through
the closure-backed `BattleRuntimeDependencies`; this package must not import or
depend on `TrinketAppState`. Cross-package contract: [battle.md](../../Docs/AgentContext/battle.md).

## UIKit feedback island

Combat floating chips use always-mounted UIKit hosts (`CombatFeedbackRasterHost`,
`CombatFeedbackChipBridge`, glyph atlas / composers) so chip publishes skip SwiftUI
battle-chrome invalidation. This is an intentional performance exception to the root
“prefer SwiftUI” guardrail.

| May enter the island | Must stay SwiftUI / State recipes |
|----------------------|-----------------------------------|
| New chip kinds via existing host + recipe/data APIs | New parallel `UIViewRepresentable` stacks |
| Raster/glyph cache tweaks measured against hitch budgets | Feature chrome, hand, battlefield layout |
| DEBUG MotionLabs that tune recipe/config values | Shipping MotionLab UI (labs stay `#if DEBUG` only) |

Do not rewrite the host for purity unless Instruments shows SwiftUI can match hitch budgets.

## Testing

```sh
./Scripts/test-package.sh TrinketBattleFeature
./Scripts/test.sh smoke SmokeBattleTests
```

Internal feedback, raster, recipe, and timing tests stay in this package rather than
making those implementation types public.
