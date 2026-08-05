# Performance Investigation Playbook

Use this for measured frame-pacing, memory, battery, or lifecycle regressions. Static review can identify leads; it cannot prove that a SwiftUI surface is slow or that a change improved it.

## Frame-pacing contract

The 60 Hz Simulator goals require every maintained scenario to average at least 59 FPS, maintain a 1% low of at least 59 FPS, and record no severe stalls. Hosted Nightly currently runs `Performance/Baselines/simulator-60.json` in `observe` mode (report findings, non-blocking); promote to `enforce` only after CI Simulator runs consistently clear those goals. Battle card play and drag handling have stricter five-repetition requirements: every repetition must maintain a 1% low of at least 59 FPS, record zero missed deadlines and severe stalls, and keep maximum frame duration at or below 20 ms.

`-enable-frame-metrics` is measurement-only. It must never remove, defer, shorten, reduce, or mute production work. The production `real-card-play` and `hand-drag-cancel` scenarios use normal XCUI gestures against the seeded hand; production views contain no forced-drag or scenario branch.

Run the exclusive matrix:

```sh
./Scripts/performance.sh
```

The runner takes the repository performance lock and uses isolated Simulator and DerivedData state. A formal Battle capture uses five repetitions:

```sh
TRINKET_PERFORMANCE_REPETITIONS=5 ./Scripts/performance.sh
```

Artifacts are written under `.DerivedData/PerformanceResults/<UTC timestamp>/`:

- `TestResults/`: xcresult, logs, and JSON attachments;
- `reports.json`: raw display-link frame reports and scenario metadata;
- `environment.json`: Xcode, host, git state, Simulator/runtime, seed, and repetition metadata;
- `summary.md`: individual gate results and frame-time diagnostics;
- `aggregate.json` and `aggregate.md`: every repetition plus median and spread.

The current runtime does not reliably export `XCTHitchMetric`; the broken exporter is intentionally absent. Do not substitute a custom `CADisplayLink` sample for an authoritative render-pipeline hitch metric. Capture Instruments Animation Hitches and Time Profiler traces when diagnosing a failure.

## Coverage inventory

| Product area | Automated performance coverage |
|---|---|
| App startup | Native `XCTApplicationLaunchMetric` from terminated state to responsive Play UI |
| Global navigation | Repeated Play → Collection → Homestead → Options → Play transitions |
| Collection | Combatant-detail sheet presentation/dismissal |
| Homestead | Seeded project-detail push/pop |
| Campaign | Stage Select navigation, enemy detail, and real Battle entry/retreat |
| Battle | Six scenarios covering real play, drag return, engine/hand, feedback, turn transition, and combined work |
| Victory / mystery | Deterministic reveal-settle scenarios |

The local matrix does not model CloudKit/network variability, persistence recovery, long-session memory or thermal behavior, or production population trends. Add those as separate deterministic scenarios instead of changing an existing scenario's production behavior.

## Battle scenario matrix

The Battle matrix is deliberately small:

1. `real-card-play`: a real press, drag, armed release, immediate removal/reflow, feedback, swing, audio/haptics, and SwiftUI cast.
2. `hand-drag-cancel`: repeated real press/drag/cancel gestures and spring return without changing hand membership.
3. `engine-hand`: card resolution, direct stored-state mutation, and projection publication without feedback decoration.
4. `engine-feedback`: card resolution plus production feedback publication.
5. `turn-transition`: production end-turn and hand projection work.
6. `combined-worst-case`: feedback, engine, swing, and the normal SwiftUI cast together.

All use the deterministic Battle performance fixture. Component cases isolate ownership boundaries; they are not alternate product implementations. Removed face-only, mask-only, particle-only, retained-host, owner-option, and synthetic-stack cases must not be reintroduced unless a new trace demonstrates a specific need.

For fast iteration, set `TRINKET_PERFORMANCE_QUICK=1`. Omit quick mode for formal artifacts. The display-link sampler discards its configured warmup after reset; deterministic stimulus begins only after the harness reports `measuring:`.

## Signals

The display-link report describes delivered callbacks:

| Signal | Meaning |
|---|---|
| `expectedFPS` | Cadence observed from `CADisplayLink.targetTimestamp` |
| `averageFPS` | Secondary throughput signal, not a smoothness guarantee |
| `p95FrameMs`, `p99FrameMs` | Long-tail delivered-frame durations |
| `onePercentLowFPS` | Average delivered FPS across the slowest 1% of frames |
| `missedDeadlineCount` / ratio | Intervals at least 1.5 observed display periods |
| `estimatedMissedFrameCount` | Estimated presentation opportunities lost across long intervals |
| `severeStallCount` | Intervals at least three observed display periods |
| `maxFrameMs` | Longest delivered interval |

Do not describe an average as a “60 FPS floor.” The five-run hard gate evaluates each card-play and drag repetition, not only the median.

## Ordered Battle investigation

Run these stages without skipping ahead:

1. `engine-hand`: verify engine resolution plus projection construction/publication fits within 8 ms and the scenario passes its frame gate.
2. `engine-feedback`: determine whether feedback publication is the added cost.
3. `real-card-play` and `hand-drag-cancel`: measure normal gestures, fan reflow, and full presentation.
4. `turn-transition` and `combined-worst-case`: confirm adjacent Battle behavior did not regress.

If engine/hand fails, profile and simplify engine mutation or projection invalidation before touching rendering. If engine/hand passes and engine/feedback fails, make feedback publication one pass: build each item once, partition immediate/scheduled items while deriving the earliest wake, compute reactions and SFX once, apply the host once, and update one timer. Preserve `availableAt`, expiration, stagger, SFX, reactions, and keyword timing.

Do not freeze slots, delay card removal, add placeholders, split user-visible work across frames, reduce feedback richness, lower asset resolution, reduce particle counts, or add another presentation framework to win a metric. Hand movement is gameplay feedback.

## Investigation loop

1. Reproduce the exact failing scenario with the same source, optimized build settings, seed, duration, Xcode, runtime, and Simulator.
2. Compare all five individual reports and their aggregate. A median must not hide a failing repetition.
3. Profile the failing stage with Animation Hitches and Time Profiler. DEBUG signposts in subsystem `com.trinket.framepacing` separately identify engine resolution, projection publication, feedback preparation, and return to the next display callback. None alone represents the full rendered frame.
4. Identify an app-attributed stack, observation invalidation, layout pass, or rendering phase. Simulator scheduling noise alone is not an app regression.
5. Make one small change that removes work or code while preserving/improving intended gameplay feel.
6. Run the focused stage again, then the full six-scenario Battle matrix.

Prefer direct stored-state mutation, one projection publication, narrow observation, cached immutable geometry, equatable static faces, bounded/preallocated resources, and parked idle clocks. Delete dead wrappers and redundant passes before adding abstractions.

## Device and production evidence

Simulator evidence is the implementation gate for the current migration, not physical-device validation. Before claiming ProMotion performance, pin a supported iPhone/OS, derive cadence from the display link, capture Instruments traces on-device, and record thermal state and Low Power Mode.

MetricKit `MXAnimationMetric.hitchTimeRatio` remains production trend evidence. It complements—and does not replace—reproducible local scenarios and Instruments traces.

## Reporting

Report the source revision/dirty state, Xcode, Simulator model/runtime, seed, optimized build settings, duration, all five individual results, aggregate spread, failing stage, Instruments evidence when available, production LOC before/after, and functional verification. If any input or evidence is missing, record the limitation and do not claim an improvement.

Apple references: [Animation hitches](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app), [Optimize for variable refresh-rate displays](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays), and [MXAnimationMetric hitch time ratio](https://developer.apple.com/documentation/metrickit/mxanimationmetric/hitchtimeratio).
