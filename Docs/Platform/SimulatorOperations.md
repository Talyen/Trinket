# Simulator and local Xcode operations

## Isolation rules

- Agents use `--isolate` and the managed `Trinket Agent N` pool (Simulator.app
  name **Trinket Agent 1**, **Trinket Agent 2**, …). Never run ad-hoc
  `simctl shutdown all` or erase shared devices.
- Humans omit isolation. The `run` alias and local tests use **Trinket Run**
  (formerly named `Trinket CI` — that name meant the shared local device, not
  GitHub Actions).
- Close SwiftUI Previews before long verification runs. Set
  `TRINKET_CLEANUP_PREVIEW_SIMS=0` only while intentionally keeping previews.
- Erase is a recovery operation after a failed cold boot, not routine cleanup.

`Scripts/run-env.sh` leases a simulator and a corresponding
`.DerivedData/runs/agent-N/` tree. Top-level cleanup preserves one warm managed
device, reclaims preview devices, and age-prunes bulky artifacts. Nested commands
release only their own leases. Never kill foreign Xcode or Simulator processes.
A lease left by a crashed run is reaped when its pid is dead or its age exceeds
`TRINKET_SLOT_STALE_SECONDS` (default 6h) — the age cap defeats pid reuse, so
stale leases never block the agent pool permanently.

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
