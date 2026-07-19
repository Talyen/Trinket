# Battle performance simplification and responsiveness

**Status:** Simplified architecture implemented; simulator performance acceptance passed.
**Goal:** Make card handling and play consistently fluid while reducing Battle production code and preserving the intended fan, drag, reflow, feedback, swing, audio, haptics, and cast behavior.
**Acceptance source:** Five optimized runs on one pinned Simulator/runtime. Physical-iPhone profiling is deferred.

## Final architecture

Battle uses one direct card-play path:

1. `BattleView` creates the cast request from the held card's release-time pose and timestamp.
2. `BattleSession.playCard` mutates its stored `BattleState` directly, builds and publishes one fine-grained presentation snapshot, publishes resolved feedback/outcome work, and returns `.rejected` or `.committed(earnedGold:)`.
3. On success, `BattleView` completes an already-claimed stage victory when necessary, starts the correct owner swing, and appends the original request to the single SwiftUI cast lane.

There is no commit owner, request wrapper, command bus, retained cast host, snapshot pool, weak bridge, dual presentation lane, or scenario-controlled production path. Card play does not cross a newly introduced task or dispatch boundary. Existing feedback stagger and hit-reaction scheduling remain intact.

The hand remains fully dynamic. Cards are keyed by identity, the active gesture is local to its card, and sibling cards spring immediately into their new fan positions after removal. The hand calculates immutable poses once for each width/card-membership rendering pass and passes them to equatable card faces, avoiding repeated fan derivation and unchanged face redraws during a drag.

Feedback retains its already-mounted, preallocated raster host and parks idle clocks. Release builds do not collect allocation diagnostics. Feedback publication now creates and schedules each item in one pass, publishes one host insertion, and updates one timer.

Balance sweeps, simulation policies, the headless simulator, and report generation live in the app-unlinked `BattleBalanceTools` target. `BattleEngine` contains runtime combat mechanics. The target split must not change abilities, modifiers, RNG, persistence, event order, or combat outcomes.

## Deleted migration surface

The simplification removes the retained cast host, card snapshot pool, cast bridge, commit display probe, commit owner/request/options/wrappers, forced-drag production branches, dual cast fallback routing, retained-host diagnostics/parity tests, native hitch export plumbing, and obsolete scenario variants. The final repository change-budget report versus `HEAD` deletes 1,988 production lines, adds 1,150, and is net −838. The remaining runtime commit/presentation ownership surface is 550 lines:

| File | Lines |
|---|---:|
| `Trinket/Features/Battle/BattleView.swift` | 474 |
| `Trinket/State/BattleSession+CardPlay.swift` | 76 |
| **Total** | **550** |

Performance-only harness/driver code is 238 additional DEBUG-only lines and is not part of runtime orchestration. The repository-wide change-budget count includes pre-existing working-tree edits; the 550-line ownership count is scoped to this migration's runtime commit path.

## Measurement contract

The Battle matrix contains only six production-relevant scenarios:

- `real-card-play`
- `hand-drag-cancel`
- `engine-hand`
- `engine-feedback`
- `turn-transition`
- `combined-worst-case`

`real-card-play` and `hand-drag-cancel` use normal XCUI press/drag/release gestures against the seeded playable card. They do not inject drag state into production views. Component scenarios use the same deterministic fixture and exist only to identify the failing layer.

The custom display-link report is a deterministic diagnostic for delivered frame intervals. It is not an authoritative render-pipeline hitch metric. The unsupported `XCTHitchMetric` exporter has been removed; use Instruments Animation Hitches and Time Profiler traces when investigating a failed gate. DEBUG signposts separately measure engine resolution, projection publication, and feedback preparation. The measurement display link does no periodic analysis while sampling; it pauses first and builds its report once so the probe cannot create its own stalls.

Each formal capture uses the same seed, build settings, Simulator model/runtime, duration, and five repetitions. Machine aggregation retains every individual report plus median and spread. Simulator results are the gate for this migration, but are not physical-device validation.

## Ordered performance gates

Run the gates in this order:

1. `engine-hand`
2. `engine-feedback`
3. `real-card-play` and `hand-drag-cancel`
4. `turn-transition` and `combined-worst-case`

Do not add another renderer, suppress hand reflow, delay publication, reduce effects, or split visible work across frames to compensate for an earlier failing stage. If engine plus projection does not fit within 8 ms, profile and simplify that path before changing SwiftUI presentation. If `engine-hand` passes but `engine-feedback` fails, replace feedback's redundant filtering/grouping/sorting passes with one partitioning pass while preserving original timing and effects.

Every repetition of `real-card-play` and `hand-drag-cancel` must satisfy:

- 1% low FPS at least 59;
- zero missed display deadlines;
- zero severe stalls;
- maximum frame duration at most 20 ms.

Five of five runs must pass. A median cannot hide a failing repetition.

## Functional acceptance

- Engine golden tests preserve card removal, damage/healing, effects, event order, RNG, victory/defeat, and balance-tool reports.
- Typed outcomes distinguish rejection from a successful play with `nil` gold.
- Claimed-stage completion, persistence retry, owner swing, feedback publication, and the original cast pose/timestamp remain correct and exactly once.
- Real UI gestures cover pickup/tracking, armed state, successful release, denial/return, sibling reflow, hit testing, detail-opening safety, cast, swing, feedback, audio, haptics, and cleanup.
- Normal-speed review judges responsiveness and smoothness, not pixel-identical motion. Spring tuning is allowed only when it improves gameplay feel without removing movement or feedback richness.

## Evidence

Optimized stage controls on `Trinket Agent 1`, iPhone18,2 Simulator, iOS 26.5, seed `1414678862`:

| Scenario | 1% low FPS | Max frame | Missed | Severe | Result |
|---|---:|---:|---:|---:|---|
| `engine-hand` | 60 | 16.67 ms | 0 | 0 | pass |
| `engine-feedback` after one-pass publication | 60 | 16.67 ms | 0 | 0 | pass |
| `combined-worst-case` using one production play | 60 | 16.67 ms | 0 | 0 | pass |

Formal five-repetition results using one real gesture per repetition:

| Scenario | Passing runs | Median 1% low | Median max frame | Total missed | Runs with severe stalls | Result |
|---|---:|---:|---:|---:|---:|---|
| `hand-drag-cancel` | 5/5 | 60 | 16.67 ms | 0 | 0 | pass |
| `real-card-play` | 5/5 | 60 | 16.67 ms | 0 | 0 | pass |

Every individual run in both scenarios reported 60 FPS 1% low, a 16.67 ms maximum frame, zero missed deadlines, and zero severe stalls. Raw reports and machine aggregation are under `.DerivedData/PerformanceResults/final-real-play-five/` and `.DerivedData/PerformanceResults/final-drag-five/`.

For comparison, the pinned pre-fix real-play capture had a 34.29 FPS median 1% low, a 54.66 ms median maximum frame, ten total missed deadlines, and severe stalls in four of five repetitions. Those raw artifacts remain under `.DerivedData/PerformanceResults/simplification-final-formal-real/`.

The resolved real-play stalls had three independent sources that accumulated around release:

- Dynamic production signpost payloads formatted card/audio metadata synchronously. Static interval signposts remain, while those event strings were removed.
- Reading `appState.journey` and `appState.homestead` reconstructed the complete SwiftData player-save graph. Slice getters now decode only their corresponding graph child.
- Warm SFX playback still queried/started an `AVAudioPlayerNode` during impact, and the cast's asynchronously rendered eight-particle `Canvas` missed a frame when its delayed particles became active. Prepared audio voices now start during warmup, and the same deterministic eight circles use ordinary retained SwiftUI shapes with unchanged paths, delays, sizes, colors, and fades.

The original combined scenario injected a second dense synthetic feedback batch before the production play; that non-production duplication was removed after it independently caused a stall. An earlier long-run probe also sorted its growing sample buffer on the main thread every 0.5 seconds; formal results above were captured only after periodic measurement publication was removed.

The iOS 26.5 Simulator reports that the Animation Hitches instrument is unsupported. A Time Profiler all-process capture did not finalize after the test and was stopped; no native trace claim is made.

The simulator gate is complete: engine/projection, feedback, drag cancellation, and real held-card release all pass their ordered checks without suppressing hand reflow, reducing particle count, delaying publication, or introducing another presentation framework. This is not physical-device validation; iPhone profiling remains explicitly deferred.
