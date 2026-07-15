# Performance Investigation Playbook

Use this for measured frame-pacing, memory, battery, or lifecycle regressions. Static review can identify leads; it cannot prove that a SwiftUI surface is slow or that a change improved it.

## App frame-pacing contract

The current automated target is the 60 Hz Simulator lane. The player-facing objective is sustained 60 FPS, including the 1% and 0.1% lows, with no visible hitches across core navigation and Battle. A future physical-device lane will use the same refresh-normalized reports at 120 Hz; physical ProMotion evidence, not Simulator extrapolation, decides that goal.

`-enable-frame-metrics` is measurement-only. It must never remove, replace, shorten, or mute Battle work. Full card dissolve, Canvas particles, keyword bursts, Ultimate cinematics, haptics configuration, and SFX execution remain on the production paths during measurement.

Run the exclusive matrix:

```sh
./Scripts/performance.sh
```

The runner takes a repository-wide performance lock, limits Simulator UI concurrency to one, uses an isolated simulator/DerivedData tenant, and runs five iterations of every scenario. It includes a native cold-launch metric, core app journeys, and the full-fidelity Battle matrix. Override only for local iteration:

```sh
TRINKET_PERFORMANCE_REPETITIONS=1 ./Scripts/performance.sh
```

Artifacts are written under `.DerivedData/PerformanceResults/<UTC timestamp>/`:

- `TestResults/`: xcresult, native `XCTHitchMetric`, logs, and JSON attachments.
- `reports.json`: raw custom display-link reports, one per scenario iteration.
- `environment.json`: Xcode, host, commit, dirty-state, and repetition metadata.
- `summary.md`: medians, goal misses, and calibrated-baseline regression findings.

## Coverage inventory

| Product area | Automated performance coverage |
|---|---|
| App startup | Native `XCTApplicationLaunchMetric` from terminated state to responsive Play UI |
| Global navigation | Repeated Play → Collection → Homestead → Options → Play tab transitions |
| Collection | Combatant-detail sheet presentation/dismissal from the Collection root |
| Homestead | Project-detail push/pop using the seeded Wheat Field route |
| Campaign / Stage Select | Repeated mode-hub ↔ Stage Select pushes and Stage Select enemy-detail sheets |
| Battle entry | Real Stage 1-1 CTA handoff to live Battle chrome and retreat back to Stage Select |
| Battle | Idle, hand interaction, casts, feedback, particles, turn transitions, Ultimate, audio, and combined stress |

The local matrix now covers the major app roots and the highest-value transitions between them. It does not yet model post-Battle rewards, Shop/Mystery/Labyrinth end-to-end journeys, persistence recovery, CloudKit/network variability, long-session memory/thermal behavior, or production population trends. Add those as separate deterministic scenarios rather than folding unrelated work into an existing measurement.

## Deterministic scenario matrix

Core app journeys use normal UI taps and production navigation:

1. Cold launch to responsive Play UI (native launch metric; no display-link baseline row).
2. Repeated tab round trips across every app root.
3. Collection combatant detail presentation/dismissal.
4. Homestead project detail push/pop.
5. Play mode hub to Campaign Stage Select push/pop.
6. Stage Select enemy detail presentation/dismissal.
7. Stage Select CTA to a live Stage 1-1 Battle and retreat back to Stage Select.

Every scenario drives the normal Battle SwiftUI and `BattleSession` presentation paths:

1. Idle Battle.
2. Continuous hand drag/cancel motion.
3. First card cast without the cast-effect prewarm.
4. Repeated warmed card casts.
5. Maximum configured concurrent card casts.
6. Feedback chips in isolation.
7. Feedback-raster cold activation with an empty bounded pool.
8. Feedback-raster warm activation with the first production label set prepared.
9. Combatant reactions and haptics in isolation.
10. Keyword bursts in isolation.
11. Dense combat feedback plus keyword bursts.
12. Turn transition and hand reflow.
13. Full Ultimate cinematic.
14. Real SFX playback path (audio is not disabled).
15. Combined worst case.

The scenario launch argument changes stimulus only: `-battle-performance-scenario <name>`. It is DEBUG-only UI tooling and is not a gameplay mode.

The display-link sampler discards 0.75 seconds after every reset so cadence can stabilize. All deterministic stimulus must begin after that warmup. Otherwise an immediate cold transition or cast is absent from the custom 1%/0.1% report even though the native hitch metric may still observe it.

## Signals and acceptance

`XCTApplicationLaunchMetric` is authoritative for cold-start responsiveness. `XCTHitchMetric(application:)` is authoritative for the render pipeline during measured journeys. The display-link report is diagnostic and refresh-normalized:

| Signal | Meaning |
|---|---|
| `expectedFPS` | Refresh cadence observed from `CADisplayLink.targetTimestamp` |
| `averageFPS` | Secondary throughput signal; not a guarantee of smoothness |
| `p95FrameMs`, `p99FrameMs`, `p999FrameMs` | Long-tail delivered-frame durations |
| `onePercentLowFPS`, `pointOnePercentLowFPS` | Average delivered FPS across the slowest 1% and 0.1% of frames |
| `missedDeadlineCount` / ratio | Intervals at least 1.5 observed display periods |
| `estimatedMissedFrameCount` | Estimated presentation opportunities lost across long intervals |
| `severeStallCount` | Intervals at least three observed display periods |

Do not describe an average as a “60 FPS floor.” A run can average 60 and still hitch. The 60 Hz goals in `Performance/Baselines/simulator-60.json` are median average, 1% low, and 0.1% low ≥60 FPS, median p99 ≤20 ms, median missed-deadline ratio ≤0.5%, and zero median severe stalls. These are currently `observe`-only until the pinned nightly Simulator/Xcode combination has enough clean repeated runs. Then:

1. Populate each scenario's calibrated reference from repeated clean nightly runs.
2. Confirm variance is low enough that a 10% regression boundary is meaningful.
3. Change baseline mode to `enforce` and remove `continue-on-error` from the nightly job.
4. Add a path-scoped PR lane only after the nightly gate is stable.

With only hundreds of frames, the 0.1% low is effectively the single worst delivered frame. Keep it as a strict stability signal, but interpret it together with native hitches, severe stalls, and medians across repeated runs rather than as a statistically rich percentile.

## Investigation loop

1. Reproduce the exact failing scenario with the same Xcode, runtime, and Simulator/device.
2. Check the raw per-iteration spread before treating a median movement as causal.
3. Profile a release-like build with Animation Hitches and Time Profiler. Signposts use subsystem `com.trinket.framepacing`, category `BattleEffects`, with intervals for cast, burst, feedback, feedback-raster builds, Ultimate, and scenario plus metadata events for card commit, turn transition, and audio playback. Scenario completion metadata includes bounded raster-pool entries, estimated bytes, hits, builds, and evictions.
4. Identify an app-attributed stack or rendering phase. Simulator scheduling noise alone is not an app regression.
5. Make one hypothesis-driven change without changing visible Battle behavior.
6. Re-run the same scenario matrix and compare native hitch data, raw reports, and the calibrated reference.

Hotspot order includes app launch, destination construction during navigation, Stage Select → Battle state initialization, card cast/dissolve, keyword particle bursts, feedback chips, continuous hand motion/reflow, Ultimate presentation, and audio resource/playback work. Prefer pausing idle animation clocks, bounding concurrent Canvas work, compositor-friendly transforms/opacity, and prewarming only imminent resources.

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
