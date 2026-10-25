# TrinketBattleFeature

Battle lifecycle, presentation, and SwiftUI for Trinket.

## Ownership

- `BattleSession`: production `BattleRuntime`; owns lifecycle, simulation, commands,
  and presentation coordination for one battle
- `BattlePresentationState`: observable combat projection
- `BattleFeedbackLane`: feedback scheduling and bounded raster publication
- `BattleSpectacleState`: celebration and outcome timing
- Battle views, layout, effects, and outcome presentation
- Ability cards stay **3:4** full-bleed art with no face text. Party portraits stay **3:4**; enemy viewport is **4:3**. Health anchors to the bottom of each combatant’s art. Show mana only when live `maxMana > 0`. No pause control, global crystals, or other top chrome.

- Phone, Duo, and iPad retain the same stacked battlefield above the fanned hand.
  Hand artwork stays fully visible and bounded by both available dimensions;
  extra width spreads the fan instead of enlarging cards indefinitely. Wide
  viewports reserve a smaller height share for the hand so combatants stay legible. Manual
  and automatic casts share the measured hand geometry. Held artwork is constrained
  horizontally to the usable field, including its scale and rotation; drawing and
  the release request use the same projected center. Raw drag direction still owns
  play classification. Resizing cancels a
  held gesture and hides stale cast positions while preserving cast timing,
  Auto pacing, and the active battle.

Battle simulation rules remain in `BattleEngine`. App options and audio enter through
the closure-backed `BattlePresentationDependencies`; this package must not import or
depend on `TrinketAppState`. Progression capabilities are configured once by the app composition root; BattleSession
owns reward retry presentation independently of overlay mounting.
Cross-package ownership: [runtime contract](../../Docs/AgentContext/battle-runtime.md).
Read [presentation](../../Docs/AgentContext/battle-presentation.md) for display/playback changes,
and [launch/completion](../../Docs/AgentContext/battle-launch.md) for activation or award wiring.

Victory summary models and views live together in `Features/Outcome/`.
Feedback scheduling, recipes, presentation models, and sound mapping live in
`State/Feedback/`; rendering stays in `Features/Feedback/`. Debug performance
scenario drivers and harnesses live in `Support/Performance/` within this target.

## Boss lyrics

Supported boss music reveals original English words as sung, with a gold active
word and dim earlier words. Phrases clear at their final word end. The lyric overlay
sits immediately above Health inside the boss card's attack/recoil transforms;
it does not resize the battlefield or intercept combatant taps. Only arriving words
animate. A leaf-owned sampler reads actual playback time and changes view state
only at word/phrase boundaries, following resumes, seeks and loops.

The default-on Audio option can disable lyrics. Unsupported bosses, defeated bosses,
retired/prepared displays, hidden tabs, and inactive scenes do not sample. Muted,
stopped or mismatched playback clears the text. Timing metadata belongs to
[MusicManifest](../../MusicManifest/README.md#boss-lyrics), not battle state.

## Prepared artwork

BattleSession holds one balanced cache acquisition per prepared artwork name,
including configured loadout cards and portraits for active and prepared runs.
The census does not simulate an opening draw. Cast prewarm acquires artwork and
textures before enabling its live renderer. Closed-vocabulary feedback rasters
are composed off the main actor from resolved immutable inputs; the pool publishes
only results belonging to its current preparation generation. Normal battle teardown
retains shared immutable glyphs and dissolve textures for the next effect or battle;
explicit memory trimming still releases them. Retired texture preparation writes
only to its retired cache and cannot declare the replacement cache ready.
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
owns draw/cast overlap and intentional visual-only finishing taps. Dragging a card
shows no portrait recipient light; lifted cards keep the attacker's wind-up
telegraph and the resource-cost highlight only.

Auto Battle begins its cue synchronously with the play request, before the hand
renders the lift. A delayed rendering callback cannot prevent a valid play or
restart an already active cue.

`BattleCardCueState` owns transient cue identity and cleanup separately from
combat projection. `BattleState.assessCard(_:)` supplies the rules-derived
resource quote; Health and Mana costs highlight
the consumed segment of the existing bar without changing its value. Uncertain
costs use a non-quantitative highlight. Normal combat feedback owns actual results.

Denied Health costs pulse the owner's Health bar. Stale or unavailable battle
state never claims a resource problem. Inspection, backgrounding, battle changes,
and cancellation clear previews; a late cancellation cannot erase a newer cue.

## UIKit feedback island

All builds use Revised Short Rise for central combat results and smaller,
independent lower-corner feeds for beneficial and harmful status changes.
Matching effects consolidate across actions; critical contributions accent their
typed total. Layout, typography, motion, and merge lifetimes follow the
[floating combat feedback contract](../../Docs/AgentContext/battle-presentation.md#floating-combat-feedback).

The linked contract owns floating-chip eligibility and suppression. Freeze and
Stun use dedicated animations and sounds; their activation, buildup, and
skipped-action reminders do not float. Active statuses
and pending talent benefits remain inspectable in the combatant detail sheet;
there are no portrait status counters or gain strips. Engine event origin and
feedback-group identity drive this policy, never display names.

Combat floating chips use artwork-mounted UIKit hosts (`CombatFeedbackRasterHost`,
`CombatFeedbackChipBridge`, glyph atlas / composers) so chip publishes skip SwiftUI
battle-chrome invalidation. This is an intentional performance exception to the root
“prefer SwiftUI” guardrail.

| May enter the island | Must stay SwiftUI / State recipes |
|----------------------|-----------------------------------|
| New chip kinds via existing host + recipe/data APIs | New parallel `UIViewRepresentable` stacks |
| Raster/glyph cache tweaks measured against hitch budgets | Feature chrome, hand, battlefield layout |
| DEBUG MotionLabs that tune recipe/config values | Shipping MotionLab UI (labs stay `#if DEBUG` only) |

Do not rewrite the host for purity unless Instruments shows SwiftUI can match hitch budgets.

## Debug feedback comparison

Debug builds expose **Options → Feedback A/B**. Baseline uses the shipping
feedback lane, raster host, layout, motion, semantic merging and corner caps.
Balanced is the default in ordinary battles. The comparison retains the previous
Baseline on the same battlefield, portraits, glyphs and hit reactions. Both modes use fixed presentation
fixtures and never issue gameplay or save commands.

Select Single, Rapid (six differently typed hits at 140 ms), Mixed (damage,
healing and Block on one recipient), Corners, or Reactions. Replay repeats the
sample. A/B Tour runs the same five sequences first in Baseline, then Balanced;
Stop cancels playback and clears all feedback. Backgrounding cancels playback.
Use `-launch-screen options -feedback-comparison` for direct managed inspection.

Balanced retains native font/icon assets and portrait-capped 52-point travel.
Central motion peaks at 1.85× after 85 ms, settles to 1.55× by 170 ms, starts
rising at 240 ms, and fades over its final 280 ms of a 1.05-second lifetime.
Measured raster footprints prefer an 80 ms stagger and 6 points of clearance,
but each result launches within 180 ms of arrival. New numeric flights compare measured footprints before choosing a fixed center
or diagonal path, with extra vertical separation on wider paths. Complete masking
is strongly penalized in either direction: a small arrival cannot hide inside an
older pop, and a new pop cannot completely cover an older result. Damage and
healing prefer opposite sides; travel is clamped to the portrait at peak scale.
Corners and names receive fixed extra rows. Every path is chosen once: later
arrivals never move, restart, shorten, or evict earlier chips. Dense overlap is
allowed when the queue deadline arrives. Each chip keeps its full post-launch
lifetime, including names at 1.6 seconds. Matching results merge within a 250 ms
arrival gap without renewed pulse or expiry.

The Reactions sample deliberately emits two Frostfire actions 140 ms apart.
Each includes Burn and Freeze damage. Mixed includes fully blocked packets so
Trinket’s normal presentation filter admits visible Block feedback.

Native recording and review are required before judging dense overlap and readability. The browser Alchemy lab is not native Trinket evidence.

## Debug transition lab

In debug builds, open **Options → Developer → Battle Transitions**. The lab
starts on the shipping stage-picker layout with fixed Forest stages. Battle
previews the selected full-screen entrance; the battle preview offers Return to
Stages and Show Victory, and sample Loot All returns to the picker.

Controls offers Crossfade, Push Through, Arcane Curtain, and Iris Reveal, plus
Replay Entry, Replay Direct Exit, Replay Victory Return, Play Full Journey, and
Reset. Reset returns to the picker; opening Controls stops playback at the last
settled screen. All presets use the same battle-to-victory crossfade.
Each victory entry restarts the sample XP and loot reveal, including after waiting
on the battle preview.

The app supplies picker content to the debug-only generic lab. Its deterministic
battle matches the sample stage and stays suspended; the battlefield, hand, and
reward views reuse shipping components. Artwork prepares before playback.
The lab saves no progress or rewards, plays no audio or haptics, and changes no
production transitions. Motion experiments live under `Features/TransitionLab/`.

## Debug game feel preview

In debug builds, **Options → Developer → Game Feel** offers manual tap/drag
motion with baseline timing comparison, ordinary/critical sound auditions,
Astral/Unique loot paging and replay, and purchase motion. Audio uses the existing
SFX player and live Effects volume; Mute Preview affects only this lab.

Busy Combat provides five fixed overlap samples. Controls collapse while samples
run; the real feedback clock then pauses so device captures can inspect chips.
Reset Sample releases the held presentation. These are scripted presentation
fixtures using shipping views, not combat-rule or performance tests. Replays
never submit production gameplay commands, claim rewards, or change saves.

## Testing

Ordinary task checks are selected automatically by
[handoff](../../Docs/Platform/Verification.md#confidence-ladder). To select this package explicitly:

```sh
./Scripts/handoff.sh --package TrinketBattleFeature
```

Semantic feedback classification lives in `CombatFeedbackPresenterTests`. Test
exclusions and smoke ownership follow [Testing.md](../../Docs/Platform/Testing.md)
and the package `Tests/README.md`.
