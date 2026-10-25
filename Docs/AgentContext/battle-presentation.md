# Battle presentation

Use with the [common runtime contract](battle-runtime.md) for display lifetime, playback, feedback, spectacle, and leaf views. Outcome/Continue wiring also loads [launch and completion](battle-launch.md).

## Display lifetime

(Battle-side view; Play side: [ui-performance.md](ui-performance.md).)
`BattleView` captures its combat projection and spectacle references when composed.
Ending or restarting Battle cancels their work and gives the session fresh display objects instead
of clearing the objects held by outgoing views. The runtime ends or replaces the
run immediately, while the retiring view keeps its last hand, combatants, and
outcome until hidden.
Retiring views must not look up replacement display objects from the session.
The captured spectacle is supplied through the view environment for outcome presentation.
View commands use `BattleViewInput`, bound to that captured combat projection.
Replacing or ending the display revokes its card, cue, inspection, toolbar and outcome
callbacks. Auto Battle carries the same input through suspension and exits when it
is retired, independently of SwiftUI task cancellation. Configuration and card IDs
alone do not establish display lifetime.
Session-owned opening, automatic-turn, and outcome waits retain the session only
for synchronous work; suspension cannot keep an abandoned battle alive. Their
task slots cancel pending work when released, including during owner teardown.
The Auto Battle task key includes command admission: a mounted inactive preview
must start a fresh driver when its prepared run activates, even when its display
and configuration identities stay the same.

After thirty rounds without new enemy Health depletion, Auto Battle switches off
for the current run and shows an inline pause notice. This automatic stop preserves
the remembered Auto preference and cancels automatic end-turn work until the player
resumes manually or re-enables Auto. Manual card input remains available; a committed
manual play clears the notice. Play Manually dismisses it, and Retreat uses the
existing defeat flow. New runs and teardown clear the notice. No defeat or reward
is inferred from lack of progress.

Victory chrome reads a settled award derived from launch-baked quantities; do not re-derive `StageCompletion` policy inside BattleFeature outcome math. Keep shared presentation DTOs in `TrinketFeatureContracts` and lifecycle ownership in `BattleRuntime`.

Retreat immediately resolves the session as defeat and opens its reward screen,
without confirmation or the combat outcome delay. It freezes enemy Health progress
and stops combat; even zero XP shows Continue. Continue uses the normal defeat claim and returns
to the origin without completing the encounter.

Defeat shows its title and a short enemy subtitle above the same party portrait
and animated XP section used by Victory. Both party rows remain visible at zero
XP, with unchanged bars. Continue is the sole primary action below the panel and
is available while XP animates. In constrained viewports the shared reward shell
pins it in the content area while XP scrolls above. Victory's Loot All is likewise available during
the reward reveal; claiming still uses the settled award. Players retry by
re-entering the encounter from the previous screen. There is no separate artwork, battle
recap, loot section, or collection feedback. A refreshed defeat settlement resets
XP presentation when recipient progression changes. Debug launch screens
`battle-defeat` and `battle-defeat-save-failure` resolve a short simulated loss;
the latter injects one total write failure to verify automatic recovery through
the same claim path without an alert or another tap.

## Continuous card input

[Card play](../Product/CardPlay.md) owns PD-024's approved behavior, including
full-size automatic cards and intentionally visual-only finishing taps. Do not
restore animation locks or reject finishing taps as a correctness fix.

Card, opening-hand, and turn commands finish synchronously in BattleEngine.
BattleFeature publishes their final hand, resources, statuses, and eligibility
once per command. Commands return a `BattleCommandResult` after all rules settle;
no consumer callbacks run inside combat. `recordActions: true` includes played
cards and resolved actions for presentation; simulations skip that recording by
default. Resolved actions retain completion order (nested actions before their
parent), stable action and card identity, the action-start event boundary, the
selected attack classification, exclusive event membership, and actual
action-damage receipts. Receipts include redirected recipients even when
combat logging has no corresponding damage event; they never change the log.
Nested actions own their own events. BattleFeature consumes these completed records and automatic card identities. Late visual completion only removes its own cast.

The engine rejects gameplay commands after outcome. The session's finishing-tap
branch consumes only presentation hand cards and must never enter BattleEngine,
refresh gameplay projection, emit combat events, or reschedule the outcome.
The final projection preserves unplayed visible cards removed by defeat cleanup,
excluding cards actually consumed by the resolving command and its automatic
plays. It retains the three-card display cap. Subsequent ordinary availability
checks do not apply to these visual-only cards.

Regression ownership: `BattleSessionSimulationTests+CardPlayback.swift` checks
consecutive commands against direct engine resolution, independent cast cleanup,
immutable finishing results/timing, and visual hand survival after lethal
retaliation. Opening/turn readiness and suspension live in the preparation and
simulation suites; gesture inspection/drag safety uses `BattleFlowUITests`.

## Attack and impact presentation

`BattleFeedbackLane` schedules attack phases and impact delivery from resolved
actions. [Card play](../Product/CardPlay.md#turns-and-battlefield-effects) owns
approved preparation, swing, recovery and acceleration timing. Combatant motion
uses the same clock and native SwiftUI springs, retargeting from its current pose.
Recipes store named timed poses for impact/recovery and wind-up/swing/recovery.
Shared phase timing is authored once; celebration retains an independent rotation
track and scheduling lifetime.
Dodge uses a 0.16-second shallow retreat, lean, and 1.5% shrink followed by a
0.24-second eased recovery. Party cards retreat down and left from a lower pivot;
enemy cards mirror that motion up and right from an upper pivot, away from the
opponent in the portrait battlefield. The composed card and its feedback move
together. Repeated impacts reuse the existing reaction bridge and priority;
Dodge adds no input delay and retains its sound, haptics, and Reduce Motion behavior.
Each scheduled action retains its timing; later attacks by the same actor may
shorten preparation and interrupt recovery while preserving distinct ordered impacts.
Automatic card reveal and dissolve use the same scheduled swing time. Auto Battle hand departures
share the action's recorded cast identity and clock: their rise/dissolve spans
preparation and finishes at swing, followed by the ordinary particle tail. Retiming
and suspension update that same cast; hand departures never render as fly-in cards.
Their cleanup follows the scheduled end rather than a fixed delay from commitment.
Manual and automatic results publish at the action’s impact cue.
Skipped and support actions do not invent attacks.

Combatant artwork, feedback, Health and Mana bars, clipping, and borders compose
before status motion, so the whole card moves together during Stun wobble.
Attack and hit-reaction transforms wrap that composed card. Defeated enemy artwork
retains its slice-owned clipping and border without an outer frame.
Stun stars use one SwiftUI shader fill with sorted particle records instead of
rebuilding Canvas paths and paint commands each frame. The shader retains the
four-point geometry, point-sized miter strokes, shadow, core, and paint order;
launch effect prewarming exercises it before battle. Freeze snowflakes continue
to transform a cached unit path. Both retain their existing motion and cadence.
With native Reduce Motion enabled, Stun stars and Freeze crystals stay visible in
a settled static pose, Death's Door keeps a steady border, and combatant cards
omit attack lunges, impact recoil, and celebration transforms. Impact delivery,
floating results, sounds, haptics, and action timing remain unchanged.
Automatic card reveals fade at their staging position; hand deals fade and hand
reflow changes directly. Cast departures and defeated artwork fade in place
without shrinking, rising, splitting, or emitting traveling particles. Finger
tracking and its captured cast pose remain intact. All completion clocks retain
the ordinary durations.

Impact delivery groups results by the presentation beat, independent of the
engine's broader feedback group. Recoil chooses the strongest result per recipient,
including directional Block recoil and immediate DoT damage resolved by an action.
Between-turn periodic results cannot suppress an action hit or produce recoil.
Floating results, sounds, result haptics, recoil, combatant resource bars, status
artwork, and defeat artwork share impact delivery for manual plays, automatic
plays, counterattacks, and enemy actions. Hand updates and command admission remain
immediate. Optional engine playback records event-attributed combatant changes;
apply only the changed presentation fields at their owning impact. Per-field event
ordering prevents a nested action from restoring older facts after its parent.
Final command cleanup belongs to the last event’s cue. Suspension, acceleration,
and retirement use the existing action queue rather than separate status timers.
Party victory celebration waits until the enemy’s defeat is displayed.
`BattleActionPresentationTests` owns sequencing, timing, interruption, and lifecycle;
recording parity remains in BattleEngine's card tests.

## Floating combat feedback

Floating chips contain game icons and numbers, with the universal reaction-name
exception below. Freeze and Stun use their dedicated
animations and activation sounds; their activation, build-up, and skipped-action
reminders do not float. Other action-skip feedback stays icon-only. Logs, ability
descriptions, and accessibility wording remain text. No-result cards do not invent
a zero chip; card motion acknowledges their play.

`CombatFeedbackPresenter` consolidates source events before projecting final chips;
grouping retains the event and its source IDs rather than a parallel presentation DTO.
`CombatFeedbackEffectPresentation` exhaustively maps effect outcomes to descriptors
with one label rule, shared by chip projection and vocabulary prewarming.

Sniff Out shows beneficial-status + Physical icons with its prepared amount on
the recipient. A refresh replaces the visible value rather than adding numbers;
if the replacement exceeds the reserved width, emit a new flight while the old
value completes its animation. Leech preparation uses beneficial-status + Leech icons. DoT
amplification uses negative-status + keyword icons rather than implying another hit.
Direct effects from automatically played cards remain visible, while unrelated
passive benefit events retain their suppression. Healing combines restored Health
and overflow into one number, including at full Health.

### Placement and motion

Central chips use Balanced: an 85 ms pop to 1.85×, settle to 1.55× by 170 ms,
then shrink toward 1.2×. A portrait-bounded 52-point cubic ease-out rise starts at
240 ms. Numeric lifetime is 1.05 seconds, including a final 280 ms fade.
There is no player animation picker; Debug Options retains the previous Baseline
for the native feedback comparison.

Each portrait has three independent regions. Damage, DoT ticks, healing, Block
absorption, and Dodge use the center region and have no count cap. New flights
select fixed diagonal paths with vertical separation when the center is crowded. Buffs, cleanse, and
resource gains appear lower left; debuffs, control, purge, resource losses, and
Death's Door appear lower right, interpreted from the recipient's perspective.
DoT applications are status feedback; actual DoT damage uses the center region.
Stripped Block appears as a loss in the lower right and does not trigger a Block
absorption reaction.

Lower chips use 80% of the central base size, a smaller 0.85-to-1.20 pop settling
to 1.0 at 0.16 seconds, a 0.92-second lifetime with a 0.34-second fade, and no automatic rise.
Each corner fits its full reserved peak footprint within half the usable portrait
width, with an 8-point center gap, 8-point outer margins, and clearance above the
resource bars. Keep centers fixed through animation and numeric growth. The
renderer and layout use the same region-specific peak bounds.

New arrivals never move or evict older flights. The lane prefers an 80 ms stagger,
with a hard 180 ms arrival-to-launch limit. New paths compare measured projected
footprints throughout their lifetimes, strongly penalizing complete covering in
either direction. Diagonal paths and fixed rows preserve visible space when the
queue deadline forces concurrent launches. The host clamps the path to the
portrait's peak footprint; spatial-edge fading cannot prematurely evict a flight.

### Consolidation and lifetime

Matching semantic effects consolidate within a 250 ms arrival gap. Keep distinct
effect outcomes separate even when they share a keyword and style; compatible
damage and healing retain their existing aggregation families. Reserve one extra
numeric digit; wider updates emit separately. Merges keep the original launch,
path, and expiry, without a renewed pop or lifetime extension. Critical
contributions retain their accent halo and flash.

Every admitted chip completes its full animation; there are no pending-count or
corner-count evictions in Balanced. Reaction names retain 1.6 seconds. Apply
sound and hit reactions from committed results immediately, independently of the
bounded text stagger. Card inputs remain immediate; damage presentation follows
its impact cue. The Debug Baseline alone retains the earlier pushes, merge
extensions, spatial culling and two-chip corner cap for comparison.

### Host composition

Feedback hosts are composed with the artwork inside its attack and hit-reaction
transforms, including the masked halves of the enemy split/dissolve death effect.
The solid halves retire once their opacity reaches zero; the prepared masked halves
remain mounted through the dissolve.
They are not positioned by fixed battlefield anchors. Remounted death fragments
replay the bridge's live items using original timestamps and cached rasters.

### Lane and rendering invariants

- **Lifetime:** Each lane owns its bridge, live items, eviction callback and
  availability timer. Hosts bind through their session and unregister from their
  original bridge. Independent
  battles/previews may reuse IDs; publication follows lane lifetime, not mount order.
- **Retention:** Prewarm the production raster vocabulary, including glint masks;
  numeric churn cannot evict it within existing capacity. Live rasters survive cache
  eviction/remount, update when appearance changes and release on retirement,
  eviction or reset. Retain raster wrappers and source images during identity
  comparisons so recycled addresses cannot hide changes. Workers retain separate
  immutable contexts and publish only for their current preparation generation.
- **Updates and bounds:** Refresh only changed recipients and frame properties.
  Matching fragment hosts share raster resolution and animation samples while
  fitting/pushes remain independent. Invalidate fitting when membership, order,
  region, reserved geometry, portrait bounds or bottom inset changes. Availability
  deadlines still reveal queued results. Glyph/geometry caches remain bounded and
  pool-owned; clearing the pool releases them. New hosts drop obsolete contexts.
- **Paint fidelity:** Color and mask passes share a resolved draw plan. Preserve
  source-over outline order, sampling and masks; bitmap flattening changes alpha
  blending. Keep rendering/feedback clocks and the prepared death-fragment behavior.
- **Clocks and publication:** Unregister display hosts on teardown or when eviction
  leaves no unpaused chips; new/resumed feedback restarts them. Expiration participates
  in outcome timing. Suspension freezes all regions; resume shifts original clocks.
  Publish changed chips and permanent removals together. Full replacement is for
  whole-lane suspension/visibility reconciliation. Batch merging preserves reverse
  arrival order and the semantic, width and lifetime rules above.

### Verification gap

Package and UI checks cannot establish visual feel. Use managed interactive
inspection, including the [native device-interaction skill](../../.agents/skills/device-interaction/SKILL.md)
when Computer Use cannot inspect Device Hub. The debug Game Feel preview offers
fixed busy samples with a held feedback clock for layout inspection; held samples
do not establish live pacing, physical audio balance, or haptic quality.
The Dodge + Recovery sample plays both sides through complete recoveries and one
interrupted repeat before holding the feedback clock.
Check central readability and smaller lower-corner status feedback under rapid
card play, including consolidation, overlap, and portrait clipping.

## Display work lifecycle

`BattleCommandState` owns command readiness and suspension. Visual tasks and
casts never own readiness. Suspension pauses cast and attack clocks, pending
impacts, and the outcome countdown; ending/replacing a run
invalidates its startup generation and clears owned cast work without clearing
the retiring view's final hand or combatants. Callbacks retain their original
presentation owner and cannot affect a later run. The outcome deadline includes
already-queued real impacts and their feedback lifetime; finishing taps cannot
extend it. Blocking overlays (battle log, combatant detail, ability detail)
cancel pending automatic turn advancement while presented; closing the last
overlay re-evaluates eligibility and starts a fresh grace period when no cards
are playable.

## Card visibility

Hand departure coordinates use the hand's measured frame in the battle coordinate
space. Auto Battle reads that frame for each play without restarting its driving
task on resize. A frame change cancels an uncommitted press or drag and its cue;
an inspection remains held until dismissal. Layout changes never reissue committed
commands. Battlefield metrics receive the available battlefield area; the parent
composition owns any space reserved for the hand. Phone canvases through 500 points
wide retain the original 224-point hand reservation and lowered fan; fitting the
entire fan above the bottom edge must not shrink their combatants. Expanded
canvases fit the rotated hand within their available height.

Holding a hand card to inspect it preserves its held appearance and foreground
ordering through detail-sheet presentation until dismissal. It keeps its resting
fan position with press feedback; finger movement within tap slop does not translate
or tilt it. Drag tracking and horizontal bounds correction begin only after crossing
that slop. Gesture release or
cancellation during inspection must not return or play the card; dismissal
returns it with the existing hand motion.

Playable hand cards use a steady border with an animated visibility transition;
becoming playable or dismissing card detail does not pulse the border.

Hand cards remain fully opaque whenever visible, including opening and subsequent
draws. Deal motion uses offset and scale without an opacity transition. Battle
entry and exit switch visibility immediately, and the battlefield uses an identity
transition for outcome changes. Fully hidden prewarmed surfaces remain mounted;
played-card cast and dissolve effects retain their own presentation.

## Universal reaction announcements

Typed reaction events show localized names above the existing damage chips. Reuse
paired keyword colors, the glyph atlas and mask preparation, portrait raster hosts,
and the lane's shared clock. Names have no standalone icon or duplicate damage
number. Their 1.6-second lifetime is independent of numeric consolidation: pop from
90% to 108% by 140 ms, settle by 240 ms, sweep one glint from 100 to 1,100 ms, and
fade from 1,250 to 1,600 ms. Use the normal upward trajectory, holding its final
position until expiry. Fit at 1.25 times the numeric base size, without wrapping or
truncating. One or two simultaneous names use one column; three or more use two.

Retain at most three announcement groups per recipient. New groups evict old groups;
numeric merges never renew a name. Suspension, teardown, death-fragment remounts,
and portrait clipping follow the existing lane ownership and original timestamps.
Names do not delay card input. Numerical presentation sums ordinary and bonus damage
by keyword within the action, retaining distinct engine packets. Existing focal
sound selection includes bonus damage; name events themselves are silent.

Add no reaction-readiness UI, tutorial copy, or reaction rules to card descriptions.
