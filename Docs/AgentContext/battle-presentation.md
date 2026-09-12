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

## Command playback

Opening draws and turn transitions execute synchronously in BattleEngine. Their
recording callback emits checkpoints that BattleFeature projects into immutable
`BattleTransitionFrame` values; the callback never advances rules. Animated and
immediate presentation consume the same resolved transition. `BattleCommandState`
owns readiness and suspension, and all manual/automatic commands use the same gate.
Suspension pauses playback; replacing/ending a run invalidates its generation.
Do not expose incremental draw mutation to BattleFeature or derive readiness from
whether an animation task happens to exist.

Card commands can record draw batches, pre-play and removal checkpoints, and
resolved effect batches through the same boundary. Recording is scoped to the
synchronous command; retained snapshots never retain its recorder. Recording
uses an inout state boundary so recursive calls do not retain full
pre-play state copies. Card announcements accompany their cast while effect
batches retain resolution order. Pack Tactics
keeps its collect-before-play rules while presentation reveals each drawn card
immediately before its automatic play. Nested plays reuse the normal lift, cast,
and feedback lanes. A buffered card with a full visible hand uses a temporary
cast position over the hand without changing the hand or buffer. Card playback
holds command readiness and outcome presentation until the final cast settles;
scene suspension pauses playback and the cast clock.

## Card visibility

Hand cards remain fully opaque whenever visible, including opening and subsequent
draws. Deal motion uses offset and scale without an opacity transition. Battle
entry and exit switch visibility immediately, and the battlefield uses an identity
transition for outcome changes. Fully hidden prewarmed surfaces remain mounted;
played-card cast and dissolve effects retain their own presentation.
