# Battle presentation

Use with the [common runtime contract](battle-runtime.md) for display lifetime, playback, feedback, spectacle, and leaf views. Outcome/Continue wiring also loads [launch and completion](battle-launch.md).

## Display lifetime

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

## Continuous card input

[Card play](../Product/CardPlay.md) owns PD-024's approved behavior, including
full-size automatic cards and intentionally visual-only finishing taps. Do not
restore animation locks or reject finishing taps as a correctness fix.

Card, opening-hand, and turn commands finish synchronously in BattleEngine.
BattleFeature publishes their final hand, resources, statuses, and eligibility
once per command. Recording is observation only: retained state never retains
its recorder, and callbacks cannot advance rules. Ordinary card recording emits
ordered effect batches; opening/turn recording additionally reports nested
`cardPlayed` checkpoints with empty event batches so aggregate turn events remain
single-delivery. BattleFeature extracts automatic card identities, not a replay
of historical hand snapshots. Late visual completion only removes its own cast.

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

## Floating combat feedback

Each result uses the same typography and size curve whether alone or alongside
other results on that combatant. Fit an individually oversized result against
the artwork; never shrink the group or introduce smaller secondary typography
because more results are present. Arrange results in presentation order and wrap
at their peak size. The group shares pop, settling, rise, update pulse, and fade;
keyword colors and critical emphasis remain specific to each result.

Rise begins during pop settling and stays within the combatant artwork, allowing
slight edge clipping. Retiring groups continue their own trajectory during the
handoff fade; incoming results must not reposition outgoing feedback.

## Display work lifecycle

`BattleCommandState` owns command readiness and suspension. Visual tasks and
casts never own readiness. Suspension pauses cast clocks; ending/replacing a run
invalidates its startup generation and clears owned cast work without clearing
the retiring view's final hand or combatants. Callbacks retain their original
presentation owner and cannot affect a later run.

## Card visibility

Hand cards remain fully opaque whenever visible, including opening and subsequent
draws. Deal motion uses offset and scale without an opacity transition. Battle
entry and exit switch visibility immediately, and the battlefield uses an identity
transition for outcome changes. Fully hidden prewarmed surfaces remain mounted;
played-card cast and dissolve effects retain their own presentation.
