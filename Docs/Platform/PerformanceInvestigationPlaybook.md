# Frame-Pacing Investigation Playbook

Use for measured frame-pacing, memory, battery, thermal, or lifecycle regressions.

## Evidence contract

- Reproduce the exact player interaction on a named source/build, device/OS,
  toolchain, seed and optimized configuration. Keep those inputs, duration,
  thermal state and Low Power Mode comparable before/after.
- Attribute cost with Instruments before editing. Source patterns and Simulator
  observations identify leads; device traces establish shipping performance.
  Functional checks and faster automated journeys alone establish neither.
- Delivered display-link callbacks, rendered-frame hitches, CPU self-time and
  elapsed signpost intervals measure different things. Report each by its scope.
- Evaluate every requested repetition and incomplete capture. Preserve gameplay,
  artwork/pins/budgets, timing, feedback, sound and interactions; report missing
  evidence explicitly instead of claiming an improvement.

## Frame-pacing contract

`Performance/Baselines/simulator-60.json` owns the maintained scenario list,
thresholds, refresh target, and observe/enforce mode. `./Scripts/performance.sh`
interprets that baseline for manual performance diagnostics, outside routine push
CI; promote the baseline to enforce only after Simulator runs consistently clear it. Single and repeated runs
use the same baseline goals, including `scenarioGoals`
for Battle gestures. Observation mode reports threshold findings without failing;
missing, malformed, duplicate, or incompatible reports always fail.

`-enable-frame-metrics` is measurement-only. It must never remove, defer, shorten, reduce, or mute production work. The production `real-card-play` and `hand-drag-cancel` scenarios use normal XCUI gestures against the seeded hand; production views contain no forced-drag or scenario branch.

Run one exclusive, optimized pass through the manual
[performance workflow](../../.github/workflows/performance.yml). For an expressly
requested local measurement, use the explicit diagnostic opt-in:

```sh
./Scripts/performance.sh --list
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/performance.sh
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/performance.sh --group collection
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/performance.sh --scenario real-card-play
```

Scenario/group selectors combine; the runner validates the full baseline and exact
selected coverage before capture. Prerequisites run, while unselected later steps
do not. Each invocation gets a fresh directory. Optional
`TRINKET_PERFORMANCE_REPETITIONS=2` checks consistency. Cold launch records the
requested iterations plus XCTest's unrecorded warmup. Suite budgets scale with
selection/repetitions (at least 20 minutes), independently of each interaction's
60-second watchdog; explicit
`TRINKET_XCODE_WALL_TIMEOUT_SECONDS` overrides remain honored. Use `--help` for
selectors; [performance.sh](../../Scripts/performance.sh) owns budget calculation.

Set `TRINKET_PERFORMANCE_SCREENSHOTS` to a comma-separated list of scenario IDs to
retain completed-screen attachments for visual verification. Screenshots are taken
after capture freezes, not during the measured interaction.

The runner retains session-scoped results under `.DerivedData/PerformanceResults/`,
including successful calibration runs. Set `TRINKET_PERFORMANCE_OUTPUT_DIR=<path>`
to choose a fresh directory; existing directories are rejected to prevent mixing
runs. Reports follow the shared [output-retention controls](../../Scripts/Reference.md#output-retention);
keep evidence explicitly when an active investigation needs it beyond 24 hours.
If UI execution fails,
the runner still collects available reports and returns failure. Raw logs and
result bundles remain beside the reports for investigation.

The current runtime does not reliably export `XCTHitchMetric`; the broken exporter is intentionally absent. Do not substitute a custom `CADisplayLink` sample for an authoritative render-pipeline hitch metric. Capture Instruments Animation Hitches and Time Profiler traces when diagnosing a failure.

## Coverage inventory

Run the matrix through manual CI `performance.yml` dispatch. Local measurement
requires an expressly requested heavy diagnostic under [Verification](Verification.md#local-simulator-budget);
`performance.sh --list` remains a cheap local inventory query.

`Performance/Baselines/simulator-60.json` maps each measured step to its XCTest
method and group. `performance-scenarios.py` checks test-plan registration, source
methods, a matching measurement inside each registered method, missing measured
scenarios, and exact scenario/group selections. Choose coverage for materially
different rendering workloads; adding a navigation enum case does not itself
require a measurement. An unchanged shared view does not need a test for every
catalog entry.

| Area | Measured interaction families |
|---|---|
| Launch / shell | Cold launch and launch animation; tab round trip; Collection navigation; Battle activation |
| Collection | Vertical browse and combatant detail scroll; equipment scroll/search/rarity filter; talent-tree scroll |
| Battle | Real card play/cancel; turn transition and combined production worst case; populated log scroll |
| Maps / Homestead | Labyrinth map and Homestead gallery scroll |
| Outcomes / encounters | Victory/defeat reveal, victory claim/return, talent reward/choice; Mystery reward and corruption reveal |
| Diagnostic exceptions | Engine/hand and engine/feedback attribution controls; injected stall detector |

Secondary browsing/control tours are retired: onboarding and mode navigation;
Collection inspection/editing/salvage; battle inspection/Auto/retreat; Shop,
Mystery and corruption interactions; Homestead overview/build/upgrade/wallet/
collection; Options, Full Game and defeat return. Their frame-pacing regressions
can escape this matrix even when functional tests pass. The baseline supplies
current scenario membership.

Retained scenario IDs and thresholds remain stable. The physical-device baseline
retains only its existing surviving workloads; it does not gain Simulator scenarios.

Scroll scenarios perform a slow directional drag and a fast flick through newly
exposed content, including deceleration. Verify movement outside the sampling
window; do not add round trips or recovery gestures that can obscure an inert
fixture. These windows differ from older round-trip reports and must be measured
afresh before comparison. They assert movement using stable
accessibility identities or labels rather than recyclable child indices. Fixtures
must contain enough content to scroll. Short item details and the fixed resource
wallet fit their viewport; they receive presentation/interaction coverage instead
of claiming a successful content scroll. Shared long detail layouts are measured
with populated combatant/equipment content. Combatant-detail scrolling equips five
Astral items with available talents, then idles for ten seconds before gesture
capture; older Basic-loadout captures represent a lighter workload.

Functional UI and headless/package journeys own payment/ownership, onboarding,
loadout persistence, reset safety, save recovery, and StoreKit entitlement behavior.
The performance catalog retains rendering workloads, not duplicate functional
checks. Current measurement membership is owned by the baseline; distinct
functional flows do not imply a retained performance scenario.

Accessibility snapshots that establish and verify scroll motion run before and
after frame sampling. Retained combined journeys check scroll motion and return
destinations outside the measured interaction. Older reports for changed windows include
accessibility snapshot cost and are not directly comparable to new reports.

Fixtures only establish disposable prerequisites before measurement: isolated
local saves, deterministic Labyrinth maps, pending talent progress, live Battle
states near an outcome, and a populated combat log. Outcome fixtures stop before
the terminal command; normal Battle commands, settlement, and reveal remain in
the measurement path. Defeat reveal uses the existing turn-transition harness to issue the terminal
production end-turn command. Fixture flags are distinct from
`-enable-frame-metrics`, which remains measurement-only. Audio and production
artwork preparation remain enabled.

Labyrinth crafting identifiers have no reachable shipping view. External web pages,
real StoreKit/CloudKit services, thermal behavior, long-session memory, and production population trends
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

`FramePacingCapture` owns bounded interval accumulation, first-callback latency,
and frozen reports with monotonic capture boundaries, completion status, test/step
identity and launch arguments. Empty, unstarted, timed-out, overflowed, legacy-only,
or inconsistent reports cannot establish interaction coverage; older reports remain
readable for historical comparison.

The summary distinguishes **coverage failure**, **performance finding**, and
**clean observation**. Missing evidence always fails, even in observation mode.
Every ordinary scenario reports missed deadlines and its worst interval; the
existing stricter gesture goals remain in force. Passing functional assertions
alone never establishes measured coverage.

Run the deliberately negative detector validation separately:

```sh
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/performance.sh --group diagnostic
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

Use the failing interaction and trace to choose the relevant Battle stage:

1. `engine-hand`: verify engine resolution plus projection construction/publication fits within 8 ms and the scenario passes its frame gate.
2. `engine-feedback`: determine whether feedback publication is the added cost.
3. `real-card-play` and `hand-drag-cancel`: measure normal gestures, fan reflow, and full presentation.
4. `turn-transition` and `combined-worst-case`: confirm adjacent Battle behavior did not regress.

For trace-attributed feedback publication cost, consider one pass: build each item once, partition immediate/scheduled items while deriving the earliest wake, compute reactions and SFX once, apply the host once, and update one timer. Preserve `availableAt`, expiration, stagger, SFX, reactions, and keyword timing.

Do not freeze slots, delay card removal, add placeholders, split user-visible work across frames, reduce feedback richness, lower asset resolution, reduce particle counts, or add another presentation framework to win a metric. Hand movement is gameplay feedback.

Pin lifecycle belongs to [ui-performance.md](../AgentContext/ui-performance.md):
do not drop launch or imminent artwork pins, replace `PreparedArtworkCache`
hits with on-demand `Image(name)`, or lower the budgets below to reduce memory.
Budgets are tuned for
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
`PreparedArtworkCacheTests` together. Those compiled tests exercise the actual
cache function across device sizes and clamp boundaries, plus the process budget
values; they do not require a particular Swift expression. The compatibility
`check-artwork-budget.sh` command selects that suite under focused-verification
limits and is not a cheap static slice. Approval constraints remain in
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

   If host attachment rejects an app PID, first confirm it still belongs to the
   live leased Simulator app; launchctl can retain a stale entry after exit.
   Xcode 27A266a has also rejected verified live PIDs and app names on this host.
   Record the attachment failure. A bounded `sample <pid> 20 1 -file <path>` can
   provide CPU investigation leads, but is not an Instruments hitch trace and
   cannot establish render-pipeline timing. Keep instrumented and sampled runs
   separate from uninstrumented before/after comparisons.

   The wrapper waits for xctrace to report that recording ended, then waits
   for save to finish. It does not guess a serialize window. SIGINT only if
   `--time-limit` is ignored.

   Animation Hitches is unsupported on Simulator (`Hitches is not supported on
   this platform`). Capture that template on a physical device.
4. Identify an app-attributed stack, observation invalidation, layout pass, or rendering phase. A long signpost interval is elapsed time, not CPU self-time; an interval spanning animation or a scheduled callback includes waiting. A healthy CPU profile does not exclude GPU/render-server cost. Simulator scheduling noise alone is not an app regression.

   Inspect XCTest accessibility work before attributing automated-journey cost
   to the game. Scroll identity snapshots are outside capture, but normal
   XCUITest control queries and gestures still participate in automated
   journeys. Neither sampled-stack counts nor a faster automated journey alone
   proves that a particular view refactor improved rendering.

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

Preserve the existing working-set owners unless measured app work supports a
change: lazy Collection/Homestead grids, lazy Combat Log rows and bounded landing
shelves. Eager stage stacks or viewport invalidation alone do not justify a `List`
migration, cache or model layer. Prefer direct mutation, one projection publication,
narrow observation, immutable cached geometry, bounded resources and parked idle
clocks when they address the attributed cost.

## Device and production evidence

ProMotion claims require a supported iPhone/OS, observed display-link cadence,
and on-device Instruments traces under the [evidence contract](#evidence-contract).

MetricKit `MXAnimationMetric.hitchTimeRatio` supplies production trend evidence for tracked animations on iOS 26+. On iOS 18, Trinket records `scrollHitchTimeRatio`, which covers scrolling only. Keep these differently scoped metrics separate when comparing trends. They complement—and do not replace—reproducible local scenarios and Instruments traces.

### Physical-device profiling over Wi-Fi

Use the physical-device workflow with a paired, unlocked iPhone and Developer
Mode enabled. For a fresh optimized development build and a 30-second recording:

```sh
python3 Scripts/profile-device.py --device '<physical UDID>' --build --duration 30
```

Omit `--build` to reuse the installed app, or use `--app /absolute/path/Trinket.app`
to install an existing development-signed Release app. Reuse does not establish
the installed app's optimization settings; the report states that limit. Release
optimization and distribution signing are separate choices. TestFlight exports
remove `get-task-allow`; use a development-signed Release build for profiling and
retain distribution signing for TestFlight.

The wrapper selects one paired physical device, refuses ambiguous selection, and
serializes its own profiling runs per device across repository worktrees. It
checks Developer Mode and compatible developer services, completes Apple's
`xcodebuild -prepareDeviceSupport` before recording, then launches Trinket directly
with CPU and Hitches instruments. Cached symbols are reused; updates prepare the
matching OS/model/architecture symbols. Keep the phone unlocked during preparation.
See Apple's [symbol preparation guidance](https://developer.apple.com/documentation/xcode/acquiring-operating-system-symbol-information).

Resolve system-symbol mismatches by preparing support for the actual connected
device, rather than copying arbitrary newer symbol folders. If the selected Xcode
does not support that device's OS, update/select a compatible Xcode first. App
symbols are separate: retain the archive or build output and its matching Trinket
`dSYM`. The `dSYM` and recorded binary must have identical UUIDs; matching source
alone is insufficient.
See Apple's [app symbol guidance](https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information).

Each run creates a new evidence directory with logs, device/app/toolchain metadata,
the trace, exported measurement rows, and `result.json`. The default location is
`~/Library/Developer/Trinket/BuildArtifacts/profiles/`, outside disposable worktrees;
`TRINKET_SYMBOL_BACKUP_ROOT` changes the shared artifact root. An explicit `--output`
uses the supplied location, whose lifetime the caller owns. Existing output is never
overwritten. Success requires the intended iPhone and Trinket process, normal app
exit, the full requested interval, `Time limit reached`, and nonempty CPU and frame
data. A zero exit code or saved partial trace after disconnect is insufficient.
Failures retain diagnostics and return nonzero. Startup and ignored recording
limits have watchdogs; acknowledged stopping/saving has no guessed wall-clock
budget. Ctrl-C cancels only owned commands and preserves partial evidence.

Each successful recording includes a verified copy of the dSYM matching the
Trinket binary UUID observed in the trace, plus a symbol manifest. For `--build`
and `--app`, the wrapper also validates all app/framework dSYMs and preserves the
executables and available build metadata. Installed-app reuse searches retained
Release products, archives, and symbol backups; use `--symbols /absolute/path/to/dSYMs`
when the original symbols live elsewhere. Missing or mismatched symbols fail the
run while retaining its raw evidence. The wrapper symbolicates its owned trace
with the preserved dSYMs and requires named Trinket frames in a fresh export.
Retain these together; a later rebuild from the same
source is not a replacement for the original symbols.

The direct-launch path avoids the attachment and device-wide failures below;
it does not repair Apple's attachment service. Do not fall back silently to host
or device-wide data. The host-only `record-time-profiler.sh` remains for Simulator
investigation. For sustained failures, compare an explicitly confirmed USB
transport, then investigate network filtering using Apple's
[device connection guidance](https://developer.apple.com/documentation/technotes/tn3158-resolving-xcode-15-device-connection-issues).
Do not reset pairing, delete symbol caches, or weaken security settings as routine
preflight actions.

During capture, reproduce the exact interaction under the [evidence contract](#evidence-contract).

### Unresolved device evidence

Direct-launch, app-scoped CPU and Animation Hitches capture has worked over Wi-Fi;
attachment and device-wide capture remain unreliable. Launch, scrolling, Campaign
transitions and card play have recorded hitches. Their remaining causes and
shipping-device improvements need controlled attribution and matched measurements.

Existing optimizations reduce recurring Stun rendering and compositor work, and
spread hidden-root layout. Their evidence does not establish hitch elimination, a global
FPS floor, lower total launch CPU, or faster readiness. Retain native navigation,
sheet motion, artwork budgets and pinning. Full-card warmup and removal of Combat
Log navigation chrome did not justify adoption. SwiftUI attribution instrumentation
added symbol-lookup overhead, so its gesture timings are not production measurements.

Thermal/Low Power Mode, cold/settled/revisit memory, background/foreground and
direct-touch dismissal evidence remain open. Controlled refresh-cadence, first-use
artwork, equipment/shared browsing, save/reward returns and rapid-combat checks
also remain incomplete. Resume under the investigation loop when a player-visible
problem is reproducible or tools permit the missing checks.
Closed investigations do not waive these gaps or justify visual reductions.

Detailed measurements and rejected experiments remain in Git history and retained
profiles under `~/Library/Developer/Trinket/BuildArtifacts/profiles/`, especially
`iphone-investigation-20261019/` and `iphone-hitches-followup-20261019/`.
Older capture diagnostics used `.DerivedData/PerformanceResults/`. Check artifact
availability and matching binaries/symbols before reuse; historical observations
do not establish today's device, installed build, or tool reliability.

The weekly [real-player soak](PlayerCoverage.md) retains diagnostic simulator
footprint/audio observations. It supplies functional ownership and repeated-play
coverage, not hardware budgets or authoritative audible/thermal evidence.

## Memory and energy

Reproduce on a named device/OS/build configuration from a cold launch. Record
process footprint at launch, after visiting the affected surfaces, after
returning to Play, and after a representative extended session. Use Instruments
Allocations and Leaks plus Xcode Memory Graph to distinguish live caches,
retained view/session graphs, leaked objects, and transient decode peaks.
Repeat the same journey after the change and compare peaks and settled
footprint. Verify cache eviction and scene background/foreground behavior; a
lower peak that produces repeated decode churn is not automatically an
improvement. Launch and imminent-destination artwork pins are hitch prevention
(see [ui-performance.md](../AgentContext/ui-performance.md)); do not release the
first-interactive working set after warmup to lower the peak.

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
network, GPU activity, and thermal behavior before and after under the
[evidence contract](#evidence-contract).

## Reporting

Report the [evidence-contract inputs](#evidence-contract), revision/dirty state,
affected scenarios, all individual results and aggregate spread, Instruments
artifacts, functional checks, and exact limitations.

Apple references: [Animation hitches](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app), [Optimize for variable refresh-rate displays](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays), and [MXAnimationMetric hitch time ratio](https://developer.apple.com/documentation/metrickit/mxanimationmetric/hitchtimeratio).
