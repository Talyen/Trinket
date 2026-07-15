# Performance Investigation Playbook

Use this for measured frame-pacing, memory, battery, or lifecycle regressions. Static review can identify leads; it cannot prove that a SwiftUI surface is slow or that a change improved it.

## Battle frame-pacing contract

The current automated target is the 60 Hz Simulator lane. The player-facing objective is sustained 59–60 FPS with no visible Battle hitches. A future physical-device lane will use the same refresh-normalized reports at 120 Hz; physical ProMotion evidence, not Simulator extrapolation, decides that goal.

`-enable-frame-metrics` is measurement-only. It must never remove, replace, shorten, or mute Battle work. Full card dissolve, Canvas particles, keyword bursts, Ultimate cinematics, haptics configuration, and SFX execution remain on the production paths during measurement.

Run the exclusive matrix:

```sh
./Scripts/performance.sh
```

The runner takes a repository-wide Battle-performance lock, limits Simulator UI concurrency to one, uses an isolated simulator/DerivedData tenant, and runs five iterations of every scenario. Override only for local iteration:

```sh
TRINKET_PERFORMANCE_REPETITIONS=1 ./Scripts/performance.sh
```

Artifacts are written under `.DerivedData/PerformanceResults/<UTC timestamp>/`:

- `TestResults/`: xcresult, native `XCTHitchMetric`, logs, and JSON attachments.
- `reports.json`: raw custom display-link reports, one per scenario iteration.
- `environment.json`: Xcode, host, commit, dirty-state, and repetition metadata.
- `summary.md`: medians, goal misses, and calibrated-baseline regression findings.

## Deterministic scenario matrix

Every scenario drives the normal Battle SwiftUI and `BattleSession` presentation paths:

1. Idle Battle.
2. Continuous hand drag/cancel motion.
3. First card cast without the cast-effect prewarm.
4. Repeated warmed card casts.
5. Maximum configured concurrent card casts.
6. Feedback chips in isolation.
7. Combatant reactions and haptics in isolation.
8. Keyword bursts in isolation.
9. Dense combat feedback plus keyword bursts.
10. Turn transition and hand reflow.
11. Full Ultimate cinematic.
12. Real SFX playback path (audio is not disabled).
13. Combined worst case.

The scenario launch argument changes stimulus only: `-battle-performance-scenario <name>`. It is DEBUG-only UI tooling and is not a gameplay mode.

## Signals and acceptance

`XCTHitchMetric(application:)` is the authoritative automated render-pipeline signal. The display-link report is diagnostic and refresh-normalized:

| Signal | Meaning |
|---|---|
| `expectedFPS` | Refresh cadence observed from `CADisplayLink.targetTimestamp` |
| `averageFPS` | Secondary throughput signal; not a guarantee of smoothness |
| `p95FrameMs`, `p99FrameMs`, `p999FrameMs` | Long-tail delivered-frame durations |
| `onePercentLowFPS`, `pointOnePercentLowFPS` | Average delivered FPS across the slowest 1% and 0.1% of frames |
| `missedDeadlineCount` / ratio | Intervals at least 1.5 observed display periods |
| `estimatedMissedFrameCount` | Estimated presentation opportunities lost across long intervals |
| `severeStallCount` | Intervals at least three observed display periods |

Do not describe an average as a “60 FPS floor.” A run can average 60 and still hitch. The 60 Hz goals in `Performance/Baselines/simulator-60.json` are median average ≥59 FPS, median p99 ≤20 ms, median missed-deadline ratio ≤0.5%, and zero median severe stalls. These are currently `observe`-only until the pinned nightly Simulator/Xcode combination has enough clean repeated runs. Then:

1. Populate each scenario's calibrated reference from repeated clean nightly runs.
2. Confirm variance is low enough that a 10% regression boundary is meaningful.
3. Change baseline mode to `enforce` and remove `continue-on-error` from the nightly job.
4. Add a path-scoped PR lane only after the nightly gate is stable.

Short runs intentionally omit 0.1% lows: with only hundreds of frames that number is just the single worst frame. Keep raw reports; compare medians across repeated runs.

## Investigation loop

1. Reproduce the exact failing scenario with the same Xcode, runtime, and Simulator/device.
2. Check the raw per-iteration spread before treating a median movement as causal.
3. Profile a release-like build with Animation Hitches and Time Profiler. Signposts use subsystem `com.trinket.framepacing`, category `BattleEffects`, with intervals for cast, burst, feedback, Ultimate, and scenario plus metadata events for card commit, turn transition, and audio playback.
4. Identify an app-attributed stack or rendering phase. Simulator scheduling noise alone is not an app regression.
5. Make one hypothesis-driven change without changing visible Battle behavior.
6. Re-run the same scenario matrix and compare native hitch data, raw reports, and the calibrated reference.

Hotspot order remains card cast/dissolve, keyword particle bursts, feedback chips, continuous hand motion/reflow, Ultimate presentation, and audio resource/playback work. Prefer pausing idle animation clocks, bounding concurrent Canvas work, compositor-friendly transforms/opacity, and prewarming only imminent resources.

## Physical-device and production lanes

The app already opts into ProMotion with `CADisableMinimumFrameDurationOnPhone`. Before claiming 120 FPS:

1. Pin at least one supported ProMotion iPhone and OS version.
2. Run the same scenarios with expected cadence derived from the display link, not a hard-coded 8.33 ms assumption.
3. Capture Animation Hitches / Time Profiler traces on-device and define a separate `device-120` baseline.
4. Add thermal-state, Low Power Mode, and repeated warm-run metadata.

MetricKit `MXAnimationMetric.hitchTimeRatio` is the later production complement for real-player trend detection. It should not replace reproducible local scenarios or Instruments traces.

## Guardrails and reporting

- Do not move battle simulation off `@MainActor`, add weak captures, erase views, or rewrite layout because a static probe found a pattern.
- Verify scene-background behavior through the actual battle/session lifecycle.
- Profiling is not a correctness test; add focused correctness coverage when a fix changes state or lifecycle semantics.
- If hardware, Instruments, or a reproducible signal is unavailable, record the limitation and do not claim an improvement.
- Report device/runtime, Xcode, scenario, iteration spread, native hitch result, raw before/after data, identified cause, changed files, and verification.

Apple references: [XCTHitchMetric](https://developer.apple.com/documentation/xctest/xcthitchmetric), [Optimize for variable refresh-rate displays](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays), and [MXAnimationMetric hitch time ratio](https://developer.apple.com/documentation/metrickit/mxanimationmetric/hitchtimeratio).
