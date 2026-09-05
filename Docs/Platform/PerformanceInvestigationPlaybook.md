# Frame-Pacing Investigation Playbook

Use this for measured frame-pacing regressions. Static review can identify leads; it
cannot prove that a SwiftUI surface is slow or that a change improved it. Memory and
energy investigation are summarized separately in
[MemoryAndEnergyInvestigation.md](MemoryAndEnergyInvestigation.md).

## Frame-pacing contract

`Performance/Baselines/simulator-60.json` owns the maintained scenario list,
thresholds, refresh target, and observe/enforce mode. `./Scripts/performance.sh`
interprets that baseline for ad hoc investigation, not CI; promote the baseline to
enforce only after Simulator runs consistently clear it. Single and repeated runs
use the same baseline goals, including `scenarioGoals`
for Battle gestures. Observation mode reports threshold findings without failing;
missing, malformed, duplicate, or incompatible reports always fail.

`-enable-frame-metrics` is measurement-only. It must never remove, defer, shorten, reduce, or mute production work. The production `real-card-play` and `hand-drag-cancel` scenarios use normal XCUI gestures against the seeded hand; production views contain no forced-drag or scenario branch.

Run the exclusive matrix:

```sh
./Scripts/performance.sh
```

The runner takes the repository performance lock and uses isolated Simulator and
DerivedData state. Formal comparisons use five measured runs per scenario:

```sh
TRINKET_PERFORMANCE_REPETITIONS=5 ./Scripts/performance.sh
```

The runner retains session-scoped results under `.DerivedData/PerformanceResults/`,
including successful calibration runs. Set `TRINKET_PERFORMANCE_OUTPUT_DIR=<path>`
to choose a fresh directory; existing directories are rejected to prevent mixing
runs. Remove old sessions explicitly when no longer needed. If UI execution fails,
the runner still collects available reports and returns failure. Raw logs and
result bundles remain beside the reports for investigation.

The current runtime does not reliably export `XCTHitchMetric`; the broken exporter is intentionally absent. Do not substitute a custom `CADisplayLink` sample for an authoritative render-pipeline hitch metric. Capture Instruments Animation Hitches and Time Profiler traces when diagnosing a failure.

## Coverage inventory

The checked-in baseline owns the complete scenario list. The local matrix does not
model CloudKit/network variability, persistence recovery, long-session memory,
thermal behavior, victory reward reveal, mystery encounter reveal, or production
population trends; add those as separate
deterministic scenarios instead of changing an existing scenario's production
behavior.

Each app repetition relaunches and restores its starting screen before resetting
measurement. The former victory/mystery reveal cases reset the sampler *after*
the revealed screen appeared and then measured an empty action. They were removed
because those numbers did not establish reveal performance. Reintroduce coverage
only with a measurement window that starts before the production reveal trigger.

## Battle scenario matrix

The Battle matrix is deliberately small:

1. `real-card-play`: a real press, drag, armed release, immediate removal/reflow, feedback, swing, audio/haptics, and SwiftUI cast.
2. `hand-drag-cancel`: a real press/drag/cancel gesture and spring return without changing hand membership.
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

Do not describe an average as a “60 FPS floor.” Every repetition is evaluated, not only the median; enforcement is controlled by the baseline mode.

## Battle investigation stages

For a Battle regression, use the failing interaction and trace to choose the relevant stage:

1. `engine-hand`: verify engine resolution plus projection construction/publication fits within 8 ms and the scenario passes its frame gate.
2. `engine-feedback`: determine whether feedback publication is the added cost.
3. `real-card-play` and `hand-drag-cancel`: measure normal gestures, fan reflow, and full presentation.
4. `turn-transition` and `combined-worst-case`: confirm adjacent Battle behavior did not regress.

A failing engine/hand scenario is a lead, not proof of engine cost: confirm the expensive stack in the trace before changing it. If the trace attributes the added cost to feedback publication, consider one pass: build each item once, partition immediate/scheduled items while deriving the earliest wake, compute reactions and SFX once, apply the host once, and update one timer. Preserve `availableAt`, expiration, stagger, SFX, reactions, and keyword timing.

Do not freeze slots, delay card removal, add placeholders, split user-visible work across frames, reduce feedback richness, lower asset resolution, reduce particle counts, or add another presentation framework to win a metric. Hand movement is gameplay feedback.

Do not drop launch or imminent artwork pins, replace `PreparedArtworkCache`
hits with on-demand `Image(name)`, or lower `PreparedArtworkMemoryBudget` /
`NSCache.totalCostLimit` to re-target 4 GB, to reduce memory. A smaller
footprint that re-decodes on the presentation frame is a hitch regression.
Pins are the eviction defense; `NSCache` alone is not. Budgets are tuned for
the current supported working set; their enforced values are listed once below.
See [MemoryAndEnergyInvestigation.md](MemoryAndEnergyInvestigation.md) for the
device-led validation workflow.

### Artwork Budgets

These are the current enforced settings and the single prose owner for their
numeric values. Change them only with the device evidence and product approval
required below; do not infer a device-specific Jetsam threshold without a
recorded measurement.

| Budget | Value | Location |
|---|---|---|
| `NSCache.totalCostLimit` | `min(max(physicalMemory/24, 160 MiB), 260 MiB)` (6 GB→256, 8 GB→260) | `PreparedArtworkCache.configureImageBudget()` |
| `residentArtworkByteCount` | 320 MiB | `PreparedArtworkMemoryBudget` — diagnostic target 240 MiB in [MemoryAndEnergyInvestigation.md](MemoryAndEnergyInvestigation.md) to validate before enforcing |
| `steadyStateProcessByteCount` | 550 MiB | `PreparedArtworkMemoryBudget` — diagnostic target 400 MiB in [MemoryAndEnergyInvestigation.md](MemoryAndEnergyInvestigation.md) to validate before enforcing |

`physicalMemory/24` already adapts; the 160 floor and 260 cap are the product
decision. If a future agent needs to support a larger catalog, raise the cap
toward 300–320 (still safe), not the floor. Any lowering must update this
section and `AGENTS.md` Guardrails and pass `check-artwork-budget.sh`.

## Investigation loop

1. Reproduce the failing player interaction. Begin tracing before the trigger;
   keep the trace running through the visible stall. Use the same source,
   optimized build settings, seed, duration, Xcode, runtime, and target. For an
   interaction absent from the matrix, reproduce it directly under Instruments;
   passing unrelated scenarios does not establish its smoothness.
2. Compare all five individual reports and their aggregate. A median must not hide a failing repetition.
3. On device, select the hitch interval in Animation Hitches, identify whether the delay is in app commit work or rendering, and correlate it with Time Profiler stacks and app signposts. Use Simulator Time Profiler for app CPU leads. App signposts in subsystem `com.trinket.framepacing` separately identify engine resolution, projection publication, feedback preparation, and return to the next display callback. None alone represents the full rendered frame.

   On Xcode 26.4–27.0, `xctrace record --device <simulator>` deadlocks the in-sim
   DTServiceHub handshake and ignores `--time-limit`, so the recording never
   ends. Record on the host and attach to Trinket (Simulator apps are ordinary
   host processes). Do not use host `--all-processes` unless you need every
   PID: it kperf-samples the whole Mac and then symbolicates every process
   into a deferred `.trace`, which is why a 5s capture can take tens of
   seconds to save.

   ```sh
   ./Scripts/record-time-profiler.sh --output .DerivedData/PerformanceResults/tp.trace --time-limit 8s
   ```

   The wrapper waits for xctrace to report that recording ended, then waits
   for save to finish. It does not guess a serialize window. SIGINT only if
   `--time-limit` is ignored.

   Animation Hitches is unsupported on Simulator (`Hitches is not supported on
   this platform`). Capture that template on a physical device.
4. Identify an app-attributed stack, observation invalidation, layout pass, or rendering phase. A long signpost interval is elapsed time, not CPU self-time; an interval spanning animation or a scheduled callback includes waiting. A healthy CPU profile does not exclude GPU/render-server cost. Simulator scheduling noise alone is not an app regression.

   The callback sampler stores aggregate intervals, not rendered frames or a
   timestamped hitch timeline. It cannot identify which stack caused a slow
   interval. Its analyzer currently uses median expected cadence for the whole
   window, so variable-refresh device deadline counts are approximate. Do not
   add speculative signposts everywhere: add a narrow span only when the trace
   cannot distinguish two plausible owners.
5. Make one small change that removes work or code while preserving/improving intended gameplay feel.
6. Run the focused stage again, then the full six-scenario Battle matrix.

Prefer direct stored-state mutation, one projection publication, narrow observation, cached immutable geometry, equatable static faces, bounded/preallocated resources, and parked idle clocks. Delete dead wrappers and redundant passes before adding abstractions.

## Device and production evidence

Simulator evidence is the implementation gate for the current migration, not physical-device validation. Before claiming ProMotion performance, pin a supported iPhone/OS, derive cadence from the display link, capture Instruments traces on-device, and record thermal state and Low Power Mode.

MetricKit `MXAnimationMetric.hitchTimeRatio` remains production trend evidence. It complements—and does not replace—reproducible local scenarios and Instruments traces.

## Reporting

Report the source revision/dirty state, Xcode, Simulator model/runtime, seed, optimized build settings, duration, all five individual results, aggregate spread, failing stage, Instruments evidence when available, production LOC before/after, and functional verification. If any input or evidence is missing, record the limitation and do not claim an improvement.

Apple references: [Animation hitches](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app), [Optimize for variable refresh-rate displays](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays), and [MXAnimationMetric hitch time ratio](https://developer.apple.com/documentation/metrickit/mxanimationmetric/hitchtimeratio).
