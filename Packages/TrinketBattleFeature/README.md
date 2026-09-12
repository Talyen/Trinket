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
depend on `TrinketAppState`. Progression capabilities are configured once by the app composition root; BattleSession
owns reward retry presentation independently of overlay mounting.
Cross-package ownership: [runtime contract](../../Docs/AgentContext/battle-runtime.md).
Read [presentation](../../Docs/AgentContext/battle-presentation.md) for display/playback changes,
and [launch/completion](../../Docs/AgentContext/battle-launch.md) for activation or award wiring.

Cinematic playback lives in `State/BattleCinematicPlayer.swift` beside spectacle
state. Victory summary models and views live together in `Features/Outcome/`.
Feedback scheduling, recipes, presentation models, and sound mapping live in
`State/Feedback/`; rendering stays in `Features/Feedback/`. Debug performance
scenario drivers and harnesses live in `Support/Performance/` within this target.

## Prepared artwork

BattleSession holds one balanced cache acquisition per prepared artwork name.
Replacing or pruning encounters invalidates stale preparation and retains artwork
still needed by the active battle or prepared siblings. Prepared activation keeps
both committed pins and valid preparation in flight through the overlay handoff.
Discarding the last run releases its pins; cancelled or superseded requests release
their own temporary acquisitions. Shared cache and budget policy remain owned by
[TrinketFeatureSupport](../TrinketFeatureSupport/README.md) and the
[performance playbook](../../Docs/Platform/PerformanceInvestigationPlaybook.md).

## Card interaction cues

Cards remain artwork-only. Manual taps commit on release; dragging and Auto
Battle use the begin/commit/cancel cue lifecycle. The approved
[continuous input contract](../../Docs/AgentContext/battle-presentation.md#continuous-card-input)
owns draw/cast overlap and intentional visual-only finishing taps. Recipient cues
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

Combat results share a compact two-row group per originating card/action and
recipient. Matching damage types and actual healing update in place; critical
contributions briefly accent their typed total. New actions retire the previous
group over 150 ms without queuing. Groups last 950 ms with a hard 1.2-second
limit; updates never restart their rise. Party groups rise at most 24 points or
12% of portrait height, and complete animated bounds stay inside the portrait.

Only direct card benefits, damage, healing, fully blocked hits, Dodge, control
outcomes, and Death's Door float. Automatic resource/buff gains, partial Block
absorption, and routine DoT application/amplification stay quiet. Active statuses
and pending talent benefits remain inspectable in the combatant detail sheet;
there are no portrait status counters or gain strips. Engine event origin and
feedback-group identity drive this policy, never display names.

Floating feedback uses filled SF Symbols where available, with keyword-colored
icons and matching numbers outlined in dark ink. Other game surfaces retain their
own icon choices. Keep the original 0.5× → 2× → 1.8× pop and settling rise;
fit groups against the portrait's usable area, not half its height. If an outgoing
group cannot fit separately during handoff, prioritize the incoming result.

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
