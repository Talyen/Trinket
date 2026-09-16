# Battle presentation

Use with the [common runtime contract](battle-runtime.md) for display lifetime, playback, feedback, spectacle, and leaf views. Outcome/Continue wiring also loads [launch and completion](battle-launch.md).

## Display lifetime

(Battle-side view; Play side: [ui-performance.md](ui-performance.md).)
`BattleView` captures its combat projection and spectacle references when composed.
Ending Battle cancels their work and gives the session fresh display objects instead
of clearing the objects held by outgoing views. The runtime is empty immediately,
while the retiring view keeps its last hand, combatants, and outcome until hidden.
Retiring views must not look up replacement display objects from the session. The captured spectacle is supplied through the view environment,
including ultimate overlays. Each spectacle owns its cinematic players; they
release when that presentation retires, so ending a run cannot empty a visible
video layer or release a subsequent run's players.
The debug Preview Lab opts into cinematic playback through its runtime dependencies
and uses the session's preparation method, independently of the gameplay feature flag.

Victory chrome reads a settled award derived from launch-baked quantities; do not re-derive `StageCompletion` policy inside BattleFeature outcome math. Keep shared presentation DTOs in `TrinketFeatureContracts` and lifecycle ownership in `BattleRuntime`.

Defeat shows its title and a short enemy subtitle above the same party portrait
and animated XP section used by Victory. Both party rows remain visible at zero
XP, with unchanged bars. Retry is primary and Leave secondary, stacked below the
panel with a 16-point gap; both wait for XP reveal completion. There is no separate artwork, battle
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
actual direct-damage receipts. Receipts include redirected recipients even when
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
including directional Block recoil; periodic results cannot suppress a direct hit
or produce recoil. Manual floating results, sounds, result haptics, and recoil
share immediate delivery, including support results while earlier attacks are pending. Scheduled
attack phases never replay those results. Automatic plays, counterattacks,
enemy actions, and auto-battle retain combined impact delivery.
`BattleActionPresentationTests` owns sequencing, timing, interruption, and lifecycle;
recording parity remains in BattleEngine's card tests.

## Floating combat feedback

Each result uses the same typography and size curve whether alone or alongside
other results on that combatant. Fit an individually oversized result against
the artwork; never shrink the group or introduce smaller secondary typography
because more results are present. Arrange results in presentation order and wrap
at their peak size. The group shares pop, settling, rise, update pulse, and fade;
keyword colors and critical emphasis remain specific to each result.

After the 0.14-second pop settles, groups hold their size and position for 0.20
seconds before rising and shrinking within the combatant artwork, allowing slight
edge clipping. A new group on the same combatant immediately releases any remaining
stationary hold, including during pop, while scale continues naturally. Already-rising
groups keep their trajectory during the 0.15-second handoff fade; incoming results
must not reposition outgoing feedback. Other combatants and same-action merge
updates do not release or restart the hold. Unattended feedback lasts 0.95 seconds.

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

Holding a hand card to inspect it preserves its held appearance and foreground
ordering through detail-sheet presentation until dismissal. Gesture release or
cancellation during inspection must not return or play the card; dismissal
returns it with the existing hand motion.

Hand cards remain fully opaque whenever visible, including opening and subsequent
draws. Deal motion uses offset and scale without an opacity transition. Battle
entry and exit switch visibility immediately, and the battlefield uses an identity
transition for outcome changes. Fully hidden prewarmed surfaces remain mounted;
played-card cast and dissolve effects retain their own presentation.
