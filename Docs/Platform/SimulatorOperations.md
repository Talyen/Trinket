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

## Auto-mirror (isolated → human)

After a green `handoff --isolate`, the built `Trinket.app` (in
`.DerivedData/runs/agent-N/Build/Products/...`) is automatically
`simctl install`-ed to **Trinket Run** so opening Simulator.app shows the
latest verified build with no manual step. This is install-only (no launch)
to avoid killing a mid-session game; the next foreground shows the new binary.
Agent hygiene never shuts down **Trinket Run** to make room for an agent
device — the two tenants are warm concurrently — so the mirror does not need
to re-boot a device that hygiene just killed.
Package-only changes trigger a quick `build.sh` for the mirror if no app
product exists yet. Suppressed in CI (`GITHUB_ACTIONS=true`) or with
`TRINKET_PROMOTE_SKIP=1`; set `TRINKET_HANDOFF_AUTO_LAUNCH=1` to also
foreground-launch after install. Manual inspection of the isolated device
remains via `./Scripts/run-simulator.sh --isolate` or `--agent N`.

## Launch visibility

`./Scripts/run-simulator.sh` (the `run` alias) builds, installs, then ensures
`Simulator.app` is frontmost for the target device. `open -a Simulator --args
-CurrentDeviceUDID` only affects a fresh launch — when Simulator is already
running the script explicitly re-opens, activates, and re-applies the UDID so
`simctl launch` does not succeed headlessly with no window. If the window
still does not appear, run `open -a Simulator --args -CurrentDeviceUDID <UDID>`
or `open -a Simulator` and check `xcrun simctl list devices` for the `Booted`
state. `handoff --isolate` auto-mirror does not launch, so use `run` to
foreground the build.

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
