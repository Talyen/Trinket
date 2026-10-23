# Simulator and local Xcode operations

## Isolation rules

- Agents use `--isolate` and the managed `Trinket Agent N` pool (Simulator.app
  name **Trinket Agent 1**, **Trinket Agent 2**, …). Never run ad-hoc
  `simctl shutdown all` or erase shared devices.
- Humans omit isolation. The `trinket-run` alias (`alias trinket-run='cd <repo> && ./Scripts/run-simulator.sh'` — installed by `node Scripts/setup-git-safety.mjs`) and local tests use **Trinket Run**.
- Close SwiftUI Previews before long verification runs. Set
  `TRINKET_CLEANUP_PREVIEW_SIMS=0` only while intentionally keeping previews.
- Erase is a recovery operation after a failed cold boot, not routine cleanup.

`Scripts/run-env.sh` leases a simulator and a corresponding
`.DerivedData/runs/agent-N/` tree. Linked Git worktrees share simulator leases,
UI concurrency reservations, and simulator cleanup locks in the primary checkout's
`.DerivedData`; build products and generation locks stay in each checkout.
Live or ambiguous checkout-local reservations and lifetime watchers from older
script versions block new claims until their owning runs finish.
Agent simulator launches automatically record
their lease owner and device identity, including launches from nested commands.
A detached watcher waits for lease release or owner exit (OS notifications on
macOS), then allows 60 seconds for warm reuse.
It reserves the slot before shutting down the exact still-unleased agent device;
new leases, renamed human devices and foreign XCTest guests are preserved. Busy
lifecycle locks retry; a replacement registration supersedes the old watcher.
Failed or timed-out cleanup observations retry after five seconds, preserving the
ownership record and rechecking leases before another shutdown attempt.
`TRINKET_AGENT_SIM_IDLE_SECONDS` can select a 0–3600-second grace period.
No extra registration or cleanup commands are required. **Trinket Run** stays
available for human play unless the optional host idle cleanup below is enabled.
Existing top-level hygiene also reclaims unleased excess
boots. Every active lease is protected, even when multiple agents are running. In CI (`GITHUB_ACTIONS=true`) there is no human `Run`, so the
legacy single-warm rule across all managed devices still applies. Preview
devices are reclaimed and bulky artifacts age-pruned. Nested commands release
only their own leases. Cancellation stops owned child processes before EXIT
cleanup releases locks and leases (process safety: [AGENTS.md](../../AGENTS.md#protect-the-workspace)). A lease
left by a crashed run is reaped when its pid is dead. Age alone never revokes
a live owner’s lease; an ambiguous lease remains reserved for inspection.

Stale lock recovery is serialized by an adjacent `.reclaim` directory in
[`Scripts/lib/lock.sh`](../../Scripts/lib/lock.sh). Missing or malformed cleanup
lock owners also remain reserved. Interrupted recovery leaves its claim in place;
inspect the claim's `pid` and confirm recovery has stopped before removing it manually.

### Optional human-session idle cleanup

`python3 Scripts/simulator-idle-cleanup.py --install` enables a per-user macOS
LaunchAgent. It checks once per minute and, after ten minutes of observed
inactivity, gracefully shuts down **Trinket Run**. Both the background interval
and macOS's input-idle clock must reach the timeout. Device Hub, Simulator, or
Xcode in the foreground always preserves the session, including controller play
or reading without keyboard input. Input anywhere on the Mac restarts the interval.
`--idle-seconds` selects a different timeout when installing.

Live or ambiguous leases, inspection/lifetime records, builds, XCTest guests,
device commands, and Xcode Preview agents prevent cleanup. Cleanup reserves the
human run slot and agent allocation lock, then refreshes ownership and activity
before shutdown. Only the uniquely named **Trinket Run** is a shutdown candidate;
agent devices, foreign devices, and saves are never erased. After shutdown, the
tool requests a normal quit of the previously observed Device Hub/Simulator
process only when every default-set simulator is shut down, no simulator guest
processes remain (including custom device sets), and activity is still idle.
It never force quits a device UI or closes Xcode.

The job uses the primary checkout, survives login, and saves one bounded status
record at `~/.local/state/trinket-simulator-idle/status.json`. `--status` reads it;
`--check` reports current eligibility without shutting anything down, and
`--uninstall` disables the job without changing devices. Missing activity or
ownership evidence preserves the session and records the reason. This opt-in
host policy is separate from the short agent lease-release grace period.

## Inspection lease and capture

For interactive inspection, use one persistent terminal session:

```bash
./Scripts/run-simulator.sh --isolate --inspect
```

Run the command in an interactive terminal session (e.g. using `run_command` with RunPersistent or `exec_command` with `tty=true`) and retain its session. The
launcher acquires an available agent slot, builds, installs, launches, then
prints `Inspection ready` with the simulator name, UDID, bundle ID, product
path, and device UI path. Xcode 27 uses Device Hub; older Xcode uses Simulator.
It keeps its lease until you send `stop\n` through standard input, close
terminal input, or cancel the process. Confirm process exit after finishing.
Begin inspection while the command is running. Prefer native Xcode device tools
when exposed; otherwise use Computer Use. Keep its
session alive across tool calls; do not run another simulator job against its
slot during inspection.

For launch only, omit `--inspect`; the standalone launcher releases its lease
when it exits. A booted device, printed UDID, or explicit `--agent N` selects a
device but does not prove a live lease. Use `--agent N` only under an existing
parent lease for that slot; otherwise let `--isolate` acquire an available slot.

For an exact installed runtime, set `TRINKET_SIM_DEVICE_TYPE` and
`TRINKET_SIM_OS_VERSION`, for example:

```bash
TRINKET_SIM_DEVICE_TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
TRINKET_SIM_OS_VERSION=27.0 ./Scripts/run-simulator.sh --isolate --inspect
```

An exact version never falls back to a newer minor release. Missing or incompatible
profiles fail before replacing the simulator owned by the lease. The existing
`TRINKET_SIM_OS_MAJOR` selector still chooses the newest installed runtime in that
major; if both selectors are supplied, they must agree on the major.

### Computer Use

Interaction technique — viewing and operating the device window, coordinate
clicks and drags, observation discipline, and recovery from unsuccessful
actions — lives in the [ios-simulator skill](../../.agents/skills/ios-simulator/SKILL.md).
Inspection scope and stopping rules follow
[Verification.md](Verification.md#choosing-ui-verification).
If the tool cannot express a gesture's timing, use the existing gesture test or
report the limitation rather than claiming its feel was verified.

### Native Xcode inspection

The inspection terminal also owns native Xcode interaction. Type `native` to
query `xcrun mcpbridge` capabilities and create one session for the exact leased
UDID. It captures the screenshot and hierarchy into Deliverables. Type
`event <documented Xcode interaction command>` to act and capture again; the
controller supplies the session key and app identity. Read the
[device-interaction skill](../../.agents/skills/device-interaction/SKILL.md) before
input and use the latest hierarchy. `status` reports the target and routes.

Native discovery is lazy. Missing tools leave screenshot capture and Computer Use
available; a discovered capability is not proof that an interaction succeeded.
`stop`, EOF and handled cancellation close the native session before the launcher
releases the lease. Uncertain starts or failed closure retain
`.DerivedData/Deliverables/Inspection/native-session.json` for recovery and prevent
replacement sessions. A shared per-device reservation under the primary checkout's
`.DerivedData/InspectionSessions/` also blocks replacement from other worktrees;
confirmed closure removes it. Do not start a second native session with chat tools beside
the controller's session. Inspect the recovery record and Xcode before retrying;
never delete it merely to clear the guard.

Physical devices and pre-existing externally owned sessions still use the native
skill directly. The controller operates only its leased simulator and its own
bridge process. It never closes foreign Xcode workspaces or device sessions.
Neither native tools nor Computer Use guarantee Duo display routing. Host memory
pressure can still require deferring another expensive inspection or build.

### Optional evidence capture

Type `capture` in the live inspection terminal to save the leased display and
product identity under `.DerivedData/Deliverables/Inspection/`. The metadata records
the checkout revision observed at launch, not a compiled-source freshness proof;
retain the build/revision and relevant screen/state in the review. For recording
or an explicit capture destination, the
[ios-simulator skill](../../.agents/skills/ios-simulator/SKILL.md#evidence-capture)
owns the exact simctl capture commands against the leased device. A full pool means
another run owns the capacity, not permission to take its device.

Save deliverables under `.DerivedData/Deliverables/` rather than an expiring
diagnostic directory. Locked integration preserves them with revision metadata
outside the task checkout before deleting it. For an immediate durable copy of
another task-local capture, use `node Scripts/agent-worktree.mjs evidence <path...>`;
without paths it prints the durable directory for direct capture. This does not
establish that the image was inspected or the interaction was exercised.

### Duo display routing

When a Duo capture is black or input has no effect after folding, compare the
rendered display, app process and actual window dimensions before diagnosing the
game. In Xcode 27.1 RC (`27A9275`) with iOS 27.1 (`24A94232`), native interaction
reported `NotRun` for a running app, captured the inactive outer display after
unfolding, and changed orientation metadata without resizing the app. Device Hub's
pose and Rotate controls produced actual geometry changes. These are observed
tool limitations, not permission to weaken the rotation journey.

Under the live lease, `xcrun simctl io "$SIMULATOR_UDID" enumerate` identifies the
display IDs accepted by screenshot/recording `--display`. The observed outer/inner
IDs were `1`/`3`; resolve them for the current device rather than assuming that
mapping. Capture the active display explicitly when the default targets the other
screen. A readable capture establishes layout, not successful touch routing.

Follow the simulator skill's bounded observation/rebind recovery after Device Hub
changes windows. Accessibility control activation can remain usable while
coordinate gestures fail with `noWindowsAvailable`; report the unexercised gesture
instead of treating a control activation as equivalent touch evidence. If a
recorder reports resource busy, preserve foreign recordings and use one owned
recording with before/after captures rather than starting simultaneous displays.

## Optional mirror (isolated → human)

Handoff is headless by default. An expressly requested local mirror uses
`TRINKET_ALLOW_HEAVY_LOCAL=1` with `handoff.sh --isolate --mirror`; the option is
guarded because it builds and installs on **Trinket Run** when the changed paths
require an app or package build. Routine lightweight handoff cannot mirror an app.
The mirror is install-only by default; it does not launch
the game. Mirroring holds an isolated build lease and the Trinket Run lease,
builds the app once, and installs that exact product. Build or install failure
fails the requested mirror. Other agent simulators and their builds are never
selected as mirror targets or fallback products. Use the launcher when foreground
inspection is needed.

[Development commands](../../Scripts/Reference.md#development) and `Scripts/promote.sh` own mirror
commands and environment switches. A passing handoff without `--mirror` does not
mean the human simulator has the new build installed.

## Launch visibility

Simulator app builds use ad-hoc code signing through `Scripts/lib/app-build.sh`.
Keep that explicit override: the generic Xcode runner disables signing for isolated
package tests, but CloudKit-enabled app launches require the Simulator's embedded
iCloud entitlements.
`ENTITLEMENTS_ALLOWED` alone does not preserve them in an unsigned app product.

`./Scripts/run-simulator.sh` (the `trinket-run` alias) builds, installs, opens the selected
Xcode's device UI, and launches the app on the leased device. Opening Device Hub
or Simulator does not guarantee that the target screen is visible; confirm the
device selection through the [ios-simulator skill](../../.agents/skills/ios-simulator/SKILL.md). Legacy
Simulator's `-CurrentDeviceUDID` argument only affects a fresh launch. The launcher
reports UI-open failures separately from app-launch failures, so a successful
headless launch is not visual verification. An opted-in handoff mirror does not
launch by default. Agents use `./Scripts/run-simulator.sh --isolate --inspect`
to keep their lease throughout inspection.

## Xcode IDE loop

Scripted local Debug Simulator builds compile only the host architecture,
including app launches and package/test builds. This avoids compiling Intel
Simulator code on Apple silicon (and vice versa). CI (`CI=true` or
`GITHUB_ACTIONS=true`), Release configurations, and device builds retain the
SDK's standard architecture coverage. The shared build arguments own this
selection; app signing, test selection, and per-slot caches are unchanged.

Normal app compilation and simulator play omit code-coverage instrumentation;
test builds keep their test-plan coverage settings. Generated content, assets,
and project freshness are shared across simulator tenants in
`.DerivedData/GeneratedInputs/`. A preparation lock prevents two launches from
regenerating the same checkout independently; build products and simulator leases
remain separate. A verified existing tenant stamp seeds shared freshness on the
first launch, avoiding an extra generation pass.

To share build products with scripts, set Workspace Settings → Build Location to
Custom, Relative to Workspace:

- Products: `.DerivedData/Build/Products`
- Intermediates: `.DerivedData/Build/Intermediates.noindex`

Routine verification uses lightweight handoff; bounded, task-relevant package or
test diagnostics follow [execution limits](Verification.md#execution-limits).
Avoid asset generation during Swift-only work,
and avoid opening both the app project and a nested package in separate Xcode
windows. `prune-derived-data-cache.sh` safely removes old local artifacts while
keeping useful warm products.

## CrashReporter setup

Simulator guest services can show misleading crash sheets after intentional
device teardown. On a development Mac, install the Additional Tools matching
your Xcode major version from
[Apple Developer Downloads](https://developer.apple.com/download/all/?q=Additional%20Tools),
open CrashReporterPrefs, and select **Basic**. Log out or reboot afterward.

Do not unload ReportCrash system-wide. Investigate a sheet when it appears
without recent simulator teardown or accompanies a real boot/test failure.

## Watchdogs and diagnostics

The routed runner terminates only its own hung host `xcodebuild` tree; it does
not shut down simulators as a timeout response. Use the structured results and
[CI diagnostics](../AgentContext/ci-diagnostics.md) before inspecting raw logs.
Before simulator tests start, the runner records existing XCTest guests on its
leased device. Lease-owner cleanup stops surviving guests created during that run,
including suspended launches owned by `launchd_sim` rather than `xcodebuild`.
Pre-existing guests and other devices remain protected. A hard-killed owner leaves
its baseline for recovery before the next test starts on that device. A reused slot
only recovers guests when the recorded device matches its current device; failed
process snapshots prevent tests from starting without a trustworthy baseline.
Relevant timeout and pool environment-variable defaults live in `Scripts/run-env.sh`
and `Scripts/xcode-runner.sh`.
