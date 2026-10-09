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
`.DerivedData/runs/agent-N/` tree. Agent simulator launches automatically record
their lease owner and device identity, including launches from nested commands.
A detached watcher waits for lease release or owner exit (OS notifications on
macOS), then allows 60 seconds for warm reuse.
It reserves the slot before shutting down the exact still-unleased agent device;
new leases, renamed human devices and foreign XCTest guests are preserved. Busy
lifecycle locks retry; a replacement registration supersedes the old watcher.
`TRINKET_AGENT_SIM_IDLE_SECONDS` can select a 0–3600-second grace period.
No extra registration or cleanup commands are required. **Trinket Run** stays
available for human play. Existing top-level hygiene also reclaims unleased excess
boots. Every active lease is protected, even when multiple agents are running. In CI (`GITHUB_ACTIONS=true`) there is no human `Run`, so the
legacy single-warm rule across all managed devices still applies. Preview
devices are reclaimed and bulky artifacts age-pruned. Nested commands release
only their own leases. Cancellation stops owned child processes before EXIT
cleanup releases locks and leases (process safety: [AGENTS.md](../../AGENTS.md#protect-the-workspace)). A lease
left by a crashed run is reaped when its pid is dead. Age alone never revokes
a live owner’s lease; an ambiguous lease remains reserved for inspection.

## Inspection lease and capture

For interactive inspection, use one persistent terminal session:

```bash
./Scripts/run-simulator.sh --isolate --inspect
```

In Codex, call `exec_command` with `tty=true` and retain its session ID. The
launcher acquires an available agent slot, builds, installs, launches, then
prints `Inspection ready` with the simulator name, UDID, bundle ID, product
path, and device UI path. Xcode 27 uses Device Hub; older Xcode uses Simulator.
It keeps its lease until you send `stop\n` through `write_stdin`, close
terminal input, or cancel the process. Confirm process exit after finishing.
Do not wait for this command to exit before beginning Computer Use. Keep its
session alive across tool calls; do not run another simulator job against its
slot during inspection.

For launch only, omit `--inspect`; the standalone launcher releases its lease
when it exits. A booted device, printed UDID, or explicit `--agent N` selects a
device but does not prove a live lease. Use `--agent N` only under an existing
parent lease for that slot; otherwise let `--isolate` acquire an available slot.

### Computer Use

Interaction technique — viewing and operating the device window, coordinate
clicks and drags, observation discipline, and recovery from unsuccessful
actions — lives in the [ios-simulator skill](../../.agents/skills/ios-simulator/SKILL.md).
Inspection scope and stopping rules follow
[Verification.md](Verification.md#choosing-ui-verification).
If the tool cannot express a gesture's timing, use the existing gesture test or
report the limitation rather than claiming its feel was verified.

### Native Xcode inspection

For requested local device diagnostics or UI verification, the
[device-interaction skill](../../.agents/skills/device-interaction/SKILL.md) provides
Xcode's native screenshot, hierarchy, and input route. Use it when Computer Use
cannot attach to Device Hub or native device events better fit the task. Keep the
same managed simulator lease alive and target its exact UDID; an Xcode interaction
session does not reserve a Trinket simulator slot. The skill owns delegation,
session cleanup, tool mapping, and Apple's exported interaction reference.

Reuse one native interaction session for the owned inspection. Record its session
key, end it on completion, failure, or cancellation, and confirm the close before
releasing the simulator lease. Do not create replacement sessions alongside an
unresponsive one. A warm Simulator/Device Hub window and the user's play session
are separate from the expensive native interaction runtime; preserve them.
Trinket's simulator pool does not coordinate memory with Lantern or Alchemy
browser sessions. If host memory pressure is high, coordinate those expensive
inspections before starting another build; source editing can continue.

### Optional evidence capture

Computer Use observations are sufficient for routine inspection. When a saved
screenshot or recording is needed as an artifact, the
[ios-simulator skill](../../.agents/skills/ios-simulator/SKILL.md#evidence-capture)
owns the exact simctl capture commands against the leased device. A full pool means
another run owns the capacity, not permission to take its device.

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

Routine verification uses lightweight handoff; expressly requested package or
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
