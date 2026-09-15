# Frame-Pacing Investigation Playbook

Use this for measured frame-pacing regressions. Static review can identify leads; it
cannot prove that a SwiftUI surface is slow or that a change improved it. Memory,
battery, thermal, and lifecycle regressions use [Memory and energy](#memory-and-energy)
below; Simulator-only observations there are leads, not shipping evidence.

## Frame-pacing contract

`Performance/Baselines/simulator-60.json` owns the maintained scenario list,
thresholds, refresh target, and observe/enforce mode. `./Scripts/performance.sh`
interprets that baseline for ad hoc investigation, not CI; promote the baseline to
enforce only after Simulator runs consistently clear it. Single and repeated runs
use the same baseline goals, including `scenarioGoals`
for Battle gestures. Observation mode reports threshold findings without failing;
missing, malformed, duplicate, or incompatible reports always fail.

`-enable-frame-metrics` is measurement-only. It must never remove, defer, shorten, reduce, or mute production work. The production `real-card-play` and `hand-drag-cancel` scenarios use normal XCUI gestures against the seeded hand; production views contain no forced-drag or scenario branch.

Run one exclusive, optimized pass:

```sh
./Scripts/performance.sh
./Scripts/performance.sh --list
./Scripts/performance.sh --group collection
./Scripts/performance.sh --scenario real-card-play
```

Scenario and group selectors can be combined. The runner snapshots the selected
baseline and validates exactly that coverage. Test prerequisites still run, but
unselected steps after the last requested measurement do not. Each invocation
uses a new output directory: a clean rerun never erases an earlier finding.
`TRINKET_PERFORMANCE_REPETITIONS=2` is an optional consistency check, not a
prerequisite. Cold launch explicitly records the requested iteration count;
XCTest additionally performs its unrecorded warmup invocation. The suite wall-time
budget scales with selected tests and repetitions (at least 20 minutes), independently
of each interaction's 60-second watchdog. An explicit
`TRINKET_XCODE_WALL_TIMEOUT_SECONDS` override is preserved.

Set `TRINKET_PERFORMANCE_SCREENSHOTS` to a comma-separated list of scenario IDs to
retain completed-screen attachments for visual verification. Screenshots are taken
after capture freezes, not during the measured interaction.

The runner retains session-scoped results under `.DerivedData/PerformanceResults/`,
including successful calibration runs. Set `TRINKET_PERFORMANCE_OUTPUT_DIR=<path>`
to choose a fresh directory; existing directories are rejected to prevent mixing
runs. Remove old sessions explicitly when no longer needed. If UI execution fails,
the runner still collects available reports and returns failure. Raw logs and
result bundles remain beside the reports for investigation.

The current runtime does not reliably export `XCTHitchMetric`; the broken exporter is intentionally absent. Do not substitute a custom `CADisplayLink` sample for an authoritative render-pipeline hitch metric. Capture Instruments Animation Hitches and Time Profiler traces when diagnosing a failure.

## Coverage inventory

`Performance/Baselines/simulator-60.json` maps each measured step to its XCTest
method and group. `performance-scenarios.py` checks test-plan registration, source
methods, missing measured scenarios, and coverage of every `AppTab` and
`PlayLaunchDestination` case. Add coverage when adding a shipping destination or
materially different interaction; an unchanged shared view does not need a test
for every catalog entry.

| Area | Measured interaction families |
|---|---|
| Launch / starter selection | Launch animation and cover dismissal; horizontal carousel; Hero and Companion confirmation |
| Shell / Campaign | Tab round trip; Campaign scrolling, enemy detail, party shelf/selection, Battle activation, chapter advancement, Full Game boundary |
| Explore | Hub, Spires browsing/climb, Contracts scroll/refresh/party/Battle return, Labyrinth map/floor selection/inspector, Shop/Boss entry and return, floor advancement |
| Collection | Vertical browse and horizontal shelves; every category grid; Hero/Companion details; ability selection; equipment scroll/search/rarity/equip/unequip; talents and salvage |
| Battle | Real card play/cancel; engine/feedback/turn diagnostic cases; inspection; auto-battle; populated log scrolling; retreat |
| Outcomes / encounters | Victory/defeat reveal, reward claim, retry/recovery, talent reward/choice; Shop scroll/purchase/return; Mystery item inspection/reward, recruit reveal/claim, corruption picker/reveal/return |
| Homestead | Root/category/gallery browsing, build/upgrade, wallet presentation and detent resizing, material collection |
| Options / Full Game | Form scroll, sliders/toggles, reset cancel/confirm, offer dismissal, local StoreKit purchase/restore, locked-content entry |

Scroll scenarios perform a slow drag, a fast flick through newly exposed content,
and a reverse flick, including deceleration. They assert movement using stable
accessibility identities or labels rather than recyclable child indices. Fixtures
must contain enough content to scroll. Short item details and the fixed resource
wallet fit their viewport; they receive presentation/interaction coverage instead
of claiming a successful content scroll. Shared long detail layouts are measured
with populated combatant/equipment content.

Fixtures only establish disposable prerequisites before measurement: isolated
local saves, deterministic Labyrinth maps, pending talent progress, live Battle
states near an outcome, and a populated combat log. Outcome fixtures stop before
the terminal command; normal Battle commands, settlement, and reveal remain in
the measurement path. Defeat reveal uses the existing turn-transition harness to issue the terminal
production end-turn command; auto-battle controls are measured separately. Fixture flags are distinct from
`-enable-frame-metrics`, which remains measurement-only. Audio and production
artwork preparation remain enabled.

Ultimate cinematics and their Options picker are currently inactive under
`BattleFeatureFlags.ultimateCinematicAnimationsEnabled`; add an enabled cinematic
scenario when that shipping flag changes. Labyrinth crafting identifiers have no
reachable shipping view. Preview Lab, external web pages, real StoreKit/CloudKit
services, thermal behavior, long-session memory, and production population trends
are outside this Simulator matrix. Use separate device/service evidence for them.

## Battle scenario matrix

The Battle matrix is deliberately small:

1. `real-card-play`: a real press, drag, armed release, immediate removal/reflow, feedback, swing, audio/haptics, and SwiftUI cast.
2. `hand-drag-cancel`: a real press/drag/cancel gesture and spring return without changing hand membership.
3. `engine-hand`: card resolution, direct stored-state mutation, and projection publication without feedback decoration.
4. `engine-feedback`: card resolution plus production feedback publication.
5. `turn-transition`: production end-turn and hand projection work.
6. `combined-worst-case`: feedback, engine, swing, and the normal SwiftUI cast together.

All use the deterministic Battle performance fixture. Component cases isolate ownership boundaries; they are not alternate product implementations. Removed face-only, mask-only, particle-only, retained-host, owner-option, and synthetic-stack cases must not be reintroduced unless a new trace demonstrates a specific need.

`TRINKET_PERFORMANCE_QUICK=1` shortens sampler preparation only. It never shortens
an action, reveal, animation tail, or gesture. Prefer scenario selection for fast
iteration. Component diagnostics use the same explicit capture lifecycle and do
not prime extra feedback before measurement.

## Signals

The probe transitions through `preparing`, `ready`, and `measuring`, then publishes
a frozen schema-6 report. The test starts measurement before the production
trigger, asserts the destination/change, waits for the visible tail, and explicitly
finishes. The finish request includes the next display callback so a final stall
is retained. The 60-second watchdog and bounded accumulator report timeout or
overflow rather than silently truncating evidence. Split longer journeys into
separate steps.

`FramePacingCapture` owns bounded interval accumulation below the app sampler.
It retains first-callback latency and freezes completed evidence. Reports include
monotonic `captureStartedAt`, `captureEndedAt`, `measurementDuration`, completion
status, step identity, test name, and launch arguments. Empty, unstarted, timed-out,
overflowed, legacy-only, and inconsistent reports cannot establish new interaction
coverage. Older artifacts remain readable for historical comparisons.

The summary distinguishes **coverage failure**, **performance finding**, and
**clean observation**. Missing evidence always fails, even in observation mode.
Every ordinary scenario reports missed deadlines and its worst interval; the
existing stricter gesture goals remain in force. Passing functional assertions
alone never establishes measured coverage.

Run the deliberately negative detector validation separately:

```sh
./Scripts/performance.sh --group diagnostic
```

It injects a 120 ms main-thread stall and asserts that the sampler sees it. The
result is an expected performance finding, excluded from the default matrix.

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
hits with on-demand `Image(name)`, or lower the budgets below to reduce memory;
see [Memory and energy](#memory-and-energy). Pins are the eviction defense;
`NSCache` alone is not. Budgets are tuned for
the current supported working set; their enforced values are listed once below.

### Artwork Budgets

These are the current enforced settings and the single prose owner for their
numeric values. Change them only with the device evidence and product approval
required below; do not infer a device-specific Jetsam threshold without a
recorded measurement.

| Budget | Value | Location |
|---|---|---|
| `NSCache.totalCostLimit` | `min(max(physicalMemory/24, 160 MiB), 260 MiB)` (6 GB→256, 8 GB→260) | `PreparedArtworkCache.configureImageBudget()` |
| `residentArtworkByteCount` | 320 MiB | `PreparedArtworkMemoryBudget` |
| `steadyStateProcessByteCount` | 550 MiB | `PreparedArtworkMemoryBudget` |

`physicalMemory/24` already adapts; the floor and cap above are the product
decision. A larger catalog alone does not establish a safe cache increase:
measure the active working set and process footprint on representative devices.
Any approved budget change must update this section, its implementation, and
`check-artwork-budget.sh` together. Approval constraints remain in
[AGENTS.md](../../AGENTS.md#product-constraints); do not duplicate numeric
budgets there.

## Investigation loop

1. Reproduce the failing player interaction. Begin tracing before the trigger;
   keep the trace running through the visible stall. Use the same source,
   optimized build settings, seed, duration, Xcode, runtime, and target. For an
   interaction absent from the matrix, reproduce it directly under Instruments;
   passing unrelated scenarios does not establish its smoothness.
2. Inspect the individual step report. Rerun only the affected step when useful; if repetitions were requested, inspect each one as well as the aggregate. A median must not hide a failing repetition.
3. On device, select the hitch interval in Animation Hitches, identify whether the delay is in app commit work or rendering, and correlate it with Time Profiler stacks and app signposts. Use Simulator Time Profiler for app CPU leads. App signposts in subsystem `com.trinket.framepacing` separately identify engine resolution, projection publication, feedback preparation, and return to the next display callback. None alone represents the full rendered frame.

   Do not record with `xctrace --device` against a Simulator; record on the host
   and attach to Trinket (Simulator apps are ordinary host processes). Do not
   use host `--all-processes` unless you need every PID: it kperf-samples the
   whole Mac and then symbolicates every process into a deferred `.trace`,
   which is why a 5s capture can take tens of seconds to save. The wrapper
   script owns version-specific workarounds; see
   `Scripts/record-time-profiler.sh` (`--help` and header comments).

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
5. Make the simplest complete change supported by the evidence while preserving
   intended gameplay feel. Additional code can be appropriate when it removes the
   measured cost or establishes a necessary lifetime boundary.
6. Rerun the affected scenario and relevant shared consumers. Run the full Battle
   matrix when the change affects its shared boundaries or a broad comparison is
   needed; unrelated scenarios are not a mandatory iteration step.

Prefer direct stored-state mutation, one projection publication, narrow observation, cached immutable geometry, equatable static faces, bounded/preallocated resources, and parked idle clocks. Consider removing dead wrappers and redundant passes when that addresses the measured cause.

## Device and production evidence

Simulator evidence does not establish physical-device performance. Before claiming ProMotion performance, pin a supported iPhone/OS, derive cadence from the display link, capture Instruments traces on-device, and record thermal state and Low Power Mode.

MetricKit `MXAnimationMetric.hitchTimeRatio` remains production trend evidence. It complements—and does not replace—reproducible local scenarios and Instruments traces.

## Memory and energy

Use measured device evidence for memory, battery, thermal, and lifecycle regressions.
Simulator-only observations can identify leads but cannot establish a shipping
budget or improvement.

Reproduce on a named device/OS/build configuration from a cold launch. Record
process footprint at launch, after visiting the affected surfaces, after
returning to Play, and after a representative extended session. Use Instruments
Allocations and Leaks plus Xcode Memory Graph to distinguish live caches,
retained view/session graphs, leaked objects, and transient decode peaks.
Repeat the same journey after the change and compare peaks and settled
footprint. Verify cache eviction and scene background/foreground behavior; a
lower peak that produces repeated decode churn is not automatically an
improvement. Launch and imminent-destination artwork pins are hitch prevention
— do not release the first-interactive working set after warmup to lower the
peak.

For art inputs, `./Scripts/report-art-memory.sh` estimates full-catalog RGBA
decode cost. It is a catalog-sizing signal, not expected simultaneous
residency. The [art pipeline](../../ArtManifest/README.md#decoded-memory-report)
owns the catalog estimate ceiling and optional enforcement; runtime budgets
stay in [Artwork Budgets](#artwork-budgets) above.

For energy and thermal regressions, reproduce on device with Low Power Mode and
thermal state recorded. Capture Instruments Energy Log and Time Profiler for
the same fixed-duration journey. Inspect idle clocks, timers, display-link
work, audio/video playback, background tasks, persistence churn, and repeated
image decode. Confirm that backgrounding parks or cancels work and foregrounding
restores one owner without duplicate timers or playback. Compare CPU, wakeups,
network, GPU activity, and thermal behavior before and after. Report thermal
and Low Power Mode state with the revision, device, and evidence required in
[Reporting](#reporting). Do not claim a production improvement when device
evidence is missing.

## Reporting

Report the source revision/dirty state, Xcode, Simulator model/runtime, seed, optimized build settings, duration, all requested individual results, aggregate spread when repeated, affected scenarios, Instruments evidence when available, and functional verification. If any input or evidence is missing, record the limitation and do not claim an improvement.

Apple references: [Animation hitches](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app), [Optimize for variable refresh-rate displays](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays), and [MXAnimationMetric hitch time ratio](https://developer.apple.com/documentation/metrickit/mxanimationmetric/hitchtimeratio).
