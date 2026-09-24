# Battle presentation

Use with the [common runtime contract](battle-runtime.md) for display lifetime, playback, feedback, spectacle, and leaf views. Outcome/Continue wiring also loads [launch and completion](battle-launch.md).

## Display lifetime

(Battle-side view; Play side: [ui-performance.md](ui-performance.md).)
`BattleView` captures its combat projection and spectacle references when composed.
Ending or restarting Battle cancels their work and gives the session fresh display objects instead
of clearing the objects held by outgoing views. The runtime ends or replaces the
run immediately, while the retiring view keeps its last hand, combatants, and
outcome until hidden.
Retiring views must not look up replacement display objects from the session. The captured spectacle is supplied through the view environment,
including ultimate overlays. Each spectacle owns its cinematic players; they
release when that presentation retires, so ending a run cannot empty a visible
video layer or release a subsequent run's players.
The debug Preview Lab opts into cinematic playback through its runtime dependencies
and uses the session's preparation method, independently of the gameplay feature flag.

Victory chrome reads a settled award derived from launch-baked quantities; do not re-derive `StageCompletion` policy inside BattleFeature outcome math. Keep shared presentation DTOs in `TrinketFeatureContracts` and lifecycle ownership in `BattleRuntime`.

Retreat immediately resolves the session as defeat and opens its reward screen,
without confirmation or the combat outcome delay. It freezes enemy Health progress
and stops combat; even zero XP shows Continue. Continue uses the normal defeat claim and returns
to the origin without completing the encounter.

Defeat shows its title and a short enemy subtitle above the same party portrait
and animated XP section used by Victory. Both party rows remain visible at zero
XP, with unchanged bars. Continue is the sole primary action below the panel and
is available while XP animates. Victory's Loot All is likewise available during
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
once per command. Recording is observation only: retained state never retains
its recorder, and callbacks cannot advance rules. Ordinary card recording emits
ordered effect batches; opening/turn recording additionally reports nested
`cardPlayed` and `actionResolved` checkpoints with empty event batches so aggregate
turn events remain single-delivery. Resolved actions carry stable action and card
identity and the action-start event boundary, the selected attack classification,
exclusive event membership, and
actual action-damage receipts. Receipts include redirected recipients even when
combat logging has no corresponding damage event; they never change the log.
Nested actions own their own events. BattleFeature extracts these records and
automatic card identities, not a replay of historical hand snapshots. Late visual completion only removes its own cast.

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
actions. Combatant motion uses the same clock and native SwiftUI spring recipes,
retargeting from its current pose. A prepared drag commits its swing; a tap starts
0.10-second preparation for manual plays (automatic and enemy attacks retain
0.40 seconds). Later attacks by the same actor can shorten pending preparation
and interrupt recovery, while distinct impacts remain ordered. Automatic card
reveal and dissolve use the same scheduled swing time. Ultimate highlights still
start with the committed action. Manual results and recoil publish at commitment
while attacker motion continues. Skipped and support actions
do not invent attacks.

Impact delivery groups results by the presentation beat, independent of the
engine's broader feedback group. Recoil chooses the strongest result per recipient,
including directional Block recoil and immediate DoT damage resolved by an action.
Between-turn periodic results cannot suppress an action hit or produce recoil. Manual floating results, sounds, result haptics, and recoil
share immediate delivery, including support results while earlier attacks are pending. Scheduled
attack phases never replay those results. Automatic plays, counterattacks,
enemy actions, and auto-battle retain combined impact delivery.
`BattleActionPresentationTests` owns sequencing, timing, interruption, and lifecycle;
recording parity remains in BattleEngine's card tests.

## Floating combat feedback

Floating chips contain game icons and numbers. Only actual Freeze and Stun
activation events show “Frozen” and “Stunned” beside their icons. Their build-up
and skipped-action reminders do not float; other action-skip feedback stays
icon-only. Logs, ability descriptions, and accessibility wording remain text.
A later actual control activation gets its own chip, even while the previous
activation is visible. No-result cards do not invent a zero chip; card motion
acknowledges their play.

Sniff Out shows beneficial-status + Physical icons with its prepared amount on
the recipient. A refresh replaces the visible value rather than adding numbers;
if the replacement exceeds the reserved width, retire the old slot before showing
the wider value. Leech preparation uses beneficial-status + Leech icons. DoT
amplification uses negative-status + keyword icons rather than implying another hit.
Direct effects from automatically played cards remain visible, while unrelated
passive benefit events retain their suppression. Healing combines restored Health
and overflow into one number, including at full Health.

Central chips use Revised Short Rise: a 0.05-second pop, brief peak/settle/hold,
52-point cubic ease-out rise (bounded in short portraits), and a 0.34-second fade
ending at 0.92 seconds. There is no animation picker.

Each portrait has three independent regions. Damage, DoT ticks, healing, Block
absorption, and Dodge stay centered and have no count cap. Buffs, cleanse, and
resource gains appear lower left; debuffs, control, purge, resource losses, and
Death's Door appear lower right, interpreted from the recipient's perspective.
DoT applications are status feedback; actual DoT damage stays centered.

Lower chips use 80% of the central base size, a smaller 0.85-to-1.20 pop settling
to 1.0 at 0.16 seconds, the same lifetime and fade, and no automatic rise.
Each corner fits its full reserved peak footprint within half the usable portrait
width, with an 8-point center gap, 8-point outer margins, and clearance above the
resource bars. Keep centers fixed through animation and numeric growth. The
renderer and layout use the same region-specific peak bounds.

New arrivals push only their own region upward by half the largest fitted peak
height. Pushes ease out over 0.18 seconds and retarget continuously. Expiration
never pulls surviving labels back down. The spatial fade at the artwork's top
edge evicts labels permanently once they leave view.

Matching semantic effects consolidate across actions before fading begins.
Keep distinct effect outcomes separate even when they share a keyword and style;
compatible damage and healing retain their existing aggregation families.
Reserve one extra numeric digit; wider additive updates emit separately.
Central merges add 0.12 seconds of visibility, capped at 0.30 seconds beyond the
original lifetime, and replay the glint and bounded 10% pulse. Critical central
contributions retain their accent halo and flash. Corner merges update numbers or
retain identical status words and source IDs without renewed glint, pulse, or
lifetime extension.

After consolidating each complete incoming batch, publish at most two visible
chips per corner per recipient. Prioritize actual control activations and Death's
Door, then the most recently received results (event ID breaks simultaneous ties).
Permanently evict overflow through the lane's existing eviction mechanism; never
queue stale notifications or resurrect evicted chips on publication/remount.
Apply sound and hit reactions from committed results before visual culling can
hide them. Card inputs and damage presentation remain immediate.

Feedback hosts are composed with the artwork inside its attack and hit-reaction
transforms, including the masked halves of the enemy split/dissolve death effect.
They are not positioned by fixed battlefield anchors. Remounted death fragments
replay the bridge's live items using original timestamps and cached rasters.

The raster host, bridge, glyph/mask cache, and shared display clock own rendering.
Prewarm the single production vocabulary including glint masks. Frame updates
change layer properties only. Feedback expiration participates in outcome timing;
suspension freezes every region and resume shifts its original clocks.

### Verification gap

Interactive inspection remains blocked by Device Hub Computer Use timeouts.
Package and UI checks cannot establish visual feel. When inspection is available,
check central readability and smaller lower-corner status feedback under rapid
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
composition owns any space reserved for the hand.

Holding a hand card to inspect it preserves its held appearance and foreground
ordering through detail-sheet presentation until dismissal. Gesture release or
cancellation during inspection must not return or play the card; dismissal
returns it with the existing hand motion.

Hand cards remain fully opaque whenever visible, including opening and subsequent
draws. Deal motion uses offset and scale without an opacity transition. Battle
entry and exit switch visibility immediately, and the battlefield uses an identity
transition for outcome changes. Fully hidden prewarmed surfaces remain mounted;
played-card cast and dissolve effects retain their own presentation.
