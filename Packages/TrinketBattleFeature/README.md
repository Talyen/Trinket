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
depend on `TrinketAppState`. Cross-package contract: [battle-runtime.md](../../Docs/AgentContext/battle-runtime.md).

## Card interaction cues

Cards remain artwork-only. Taps use the existing 180 ms lift; dragging uses the
same begin/commit/cancel cue lifecycle, including Auto Battle. Recipient cues
use small motions and established keyword colors: contracting attack light,
rising restoration, a protective brace, an outward cleanse, gathered preparation,
and a gain/draw lift. Combined effects use one motion per recipient, preferring
cleanse, restoration, protection, attack, preparation, then gain.

Auto Battle begins its cue synchronously with the play request, before the hand
renders the lift. A delayed rendering callback cannot prevent a valid play or
restart an already active cue.

`BattleCardCueState` owns transient cue identity and cleanup separately from
combat projection. `BattleState.assessCard(_:)` supplies rules-derived intent;
random outcomes show only common recipients. Health and Mana costs highlight
the consumed segment of the existing bar without changing its value. Uncertain
costs use a non-quantitative highlight; Block-for-Mana substitution emphasizes
the payer's protection. When no stronger recipient cue applies, the payer also
receives a resource-colored preparation cue so a lifted card cannot hide all
spending feedback. Normal combat feedback owns actual results.

Denied Health costs pulse the owner's Health bar, control emphasizes the owner's
status, and defeat emphasizes the dimmed portrait. Stale or unavailable battle
state never claims a resource problem. Inspection, backgrounding, battle changes,
and cancellation clear previews; a late cancellation cannot erase a newer cue.

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
```

Semantic feedback classification lives in `CombatFeedbackPresenterTests`. Test
exclusions and smoke ownership follow [Testing.md](../../Docs/Platform/Testing.md)
and the package `Tests/README.md`.
