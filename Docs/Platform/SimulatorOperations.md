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
session (and vice versa); excess `Run` or excess `Agent` boots within a tenant
are shut down. In CI (`GITHUB_ACTIONS=true`) there is no human `Run`, so the
legacy single-warm rule across all managed devices still applies. Preview
devices are reclaimed and bulky artifacts age-pruned. Nested commands release
only their own leases. Never kill foreign Xcode or Simulator processes. A lease
left by a crashed run is reaped when its pid is dead or its age exceeds
`TRINKET_SLOT_STALE_SECONDS` (default 6h) — the age cap defeats pid reuse, so
stale leases never block the agent pool permanently.

## Inspection lease and capture

For a launch followed by screenshots, video, or UI interaction, keep one Bash
process alive for the whole inspection. From the repository root, set
`TRINKET_ISOLATE=1`, source `Scripts/run-env.sh`, and call
`trinket_run_env_init`. With no preselected slot or simulator overrides, this
acquires an available agent slot and installs its release trap. Run
`./Scripts/run-simulator.sh --isolate` as a child of that process so it inherits
the lease. Keep the parent alive until inspection finishes; its exit releases
the lease. A standalone launcher releases its lease when it exits.

Resolve the capture UDID from the leased `TRINKET_SIMULATOR_NAME` using
`Scripts/simctl_json.py udid-for-name`, and check that it resolved before issuing
commands. An explicit `--agent N` binds a slot name; it does not acquire an unused
slot and is appropriate only while you already hold that slot's lease.

With `SIMULATOR_UDID` set to that leased device:

```bash
xcrun simctl io "$SIMULATOR_UDID" screenshot /tmp/trinket-screen.png --type=png --mask=ignored
xcrun simctl io "$SIMULATOR_UDID" recordVideo /tmp/trinket-motion.mp4
```

Stop recording with SIGINT to the recording process. Use the managed shutdown
helper for recovery; it owns graceful guest-service teardown. A full pool means
another run owns the capacity, not permission to take its device.

## Optional mirror (isolated → human)

Handoff is headless by default. `handoff.sh --isolate --mirror` opts into
installing the verified app on **Trinket Run** when the changed paths require an
app or package build. The mirror is install-only by default; it does not launch
the game. Mirroring can require an app build when only package products exist.
Use the launcher when foreground inspection is needed.

[Scripts/README.md](../../Scripts/README.md) and `Scripts/promote.sh` own mirror
commands and environment switches. A passing handoff without `--mirror` does not
mean the human simulator has the new build installed.

## Launch visibility

`./Scripts/run-simulator.sh` (the `run` alias) builds, installs, then ensures
`Simulator.app` is frontmost for the target device. `open -a Simulator --args
-CurrentDeviceUDID` only affects a fresh launch — when Simulator is already
running the script explicitly re-opens, activates, and re-applies the UDID so
`simctl launch` does not succeed headlessly with no window. If the window
still does not appear, run `open -a Simulator --args -CurrentDeviceUDID <UDID>`
or `open -a Simulator` and check `xcrun simctl list devices` for the `Booted`
state. An opted-in handoff mirror does not launch by default. Agents use
`./Scripts/run-simulator.sh --isolate` to foreground their leased build.

## Xcode IDE loop

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
