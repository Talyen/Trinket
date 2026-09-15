# Simulator and local Xcode operations

## Isolation rules

- Agents use `--isolate` and the managed `Trinket Agent N` pool (Simulator.app
  name **Trinket Agent 1**, **Trinket Agent 2**, …). Never run ad-hoc
  `simctl shutdown all` or erase shared devices.
- Humans omit isolation. The `run` alias (`alias run='cd <repo> && ./Scripts/run-simulator.sh'` — installed by `node Scripts/setup-git-safety.mjs`) and local tests use **Trinket Run**.
- Close SwiftUI Previews before long verification runs. Set
  `TRINKET_CLEANUP_PREVIEW_SIMS=0` only while intentionally keeping previews.
- Erase is a recovery operation after a failed cold boot, not routine cleanup.

`Scripts/run-env.sh` leases a simulator and a corresponding
`.DerivedData/runs/agent-N/` tree. Top-level cleanup preserves warm managed
devices per tenant — one **Trinket Run** plus one **Trinket Agent N** may stay
`Booted` concurrently so an agent run never shuts down a human's `Trinket Run`
session (and vice versa); only unleased excess `Run` or `Agent` boots are shut
down. Every active lease is protected, even when multiple agents are running. In CI (`GITHUB_ACTIONS=true`) there is no human `Run`, so the
legacy single-warm rule across all managed devices still applies. Preview
devices are reclaimed and bulky artifacts age-pruned. Nested commands release
only their own leases. Cancellation stops owned child processes before EXIT
cleanup releases locks and leases. Never kill foreign Xcode or Simulator processes. A lease
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

### Optional evidence capture

Computer Use observations are sufficient for routine inspection. When a saved
screenshot or recording is needed as an artifact, the
[ios-simulator skill](../../.agents/skills/ios-simulator/SKILL.md#evidence-capture)
owns the exact simctl capture commands against the leased device. A full pool means
another run owns the capacity, not permission to take its device.

## Optional mirror (isolated → human)

Handoff is headless by default. `handoff.sh --isolate --mirror` opts into
installing the verified app on **Trinket Run** when the changed paths require an
app or package build. The mirror is install-only by default; it does not launch
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

`./Scripts/run-simulator.sh` (the `run` alias) builds, installs, opens the selected
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

To share build products with scripts, set Workspace Settings → Build Location to
Custom, Relative to Workspace:

- Products: `.DerivedData/Build/Products`
- Intermediates: `.DerivedData/Build/Intermediates.noindex`

Use scoped package or test loops. Avoid asset generation during Swift-only work,
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
Relevant timeout and pool environment-variable defaults live in `Scripts/run-env.sh`
and `Scripts/xcode-runner.sh`.
