---
name: ios-simulator
description: Launch, inspect, capture, or debug Trinket on iOS Simulator using a managed lease and Computer Use. Use before simulator operations or UI verification.
---

# Simulator inspection

For interactive inspection, run this in a persistent terminal (`exec_command`
with `tty=true`), and retain the returned session ID:

```bash
./Scripts/run-simulator.sh --isolate --inspect
```

Wait for `Inspection ready`, then use **Computer Use** (`mcp__cua_repl`) to view
and operate the matching device window in **Device Hub** (Xcode 27) or Simulator.
Use the device UI path printed by the launcher with `cua.getApp(...)`; do not
assume the old Simulator bundle identifier still resolves after an Xcode upgrade.
Follow the tool's live documentation;
its JavaScript calls are the supported interaction interface. Keep the terminal
session alive throughout inspection. Send `stop\n` to that session using
`write_stdin` when finished, and confirm the process exits.

Use managed scripts for building, installing, leases, and logs; Computer Use for
exploratory taps, drags, typing, and visual checks; existing XCTest journeys for
repeatable regression checks under [Verification.md](../../../Docs/Platform/Verification.md#choosing-ui-verification).
Do not invent AppleScript, Swift, or event-injection programs to operate the UI.
If Computer Use is unavailable, report that limitation and use an existing test
for the behavior it actually covers; do not claim interactive inspection.

[Simulator operations](../../../Docs/Platform/SimulatorOperations.md) owns lease
isolation, slot recovery, and mirror policy. This skill owns interaction
technique, recovery, and evidence capture.
A booted device or printed UDID does not prove a live lease. Never choose a fixed
agent slot merely because it appears idle. Target the leased UDID explicitly in
simctl commands, never `booted`; manage only your leased device and let the
managed helpers handle recovery and shutdown.

Confirm the window's device name matches the launcher's leased simulator before
interacting; select the leased device in Device Hub's sidebar (or Simulator) if
another device is selected. An opened app alone does not prove device selection.
Recheck the target after a window change. Observe the current screen, act, and
inspect the resulting state before choosing the next action. Prefer available
controls, and use screenshot-based coordinate clicks or drags from the current
observation when accessibility controls are absent or ineffective. After an
unsuccessful action, refresh the observation, check the target window, overlays,
and control state, and try one relevant alternative. If the same obstacle
remains, use existing focused XCTest coverage or report the limitation. Do not
write a custom input driver.

## Interaction evidence

A screenshot can verify layout; exercise the interaction to verify behavior.
Report device/build identity and what was actually checked. Treat simulator
performance and absent physical haptics as limits of that evidence. Use
[CI diagnostics](../../../Docs/AgentContext/ci-diagnostics.md) for build/test
failures, and the recovery workflow above for unsuccessful UI actions.

## Evidence capture

Observations are sufficient for routine inspection. When a saved screenshot or
recording is needed as an artifact, set `SIMULATOR_UDID` to the UDID printed by
the still-running inspection session, then:

```bash
xcrun simctl io "$SIMULATOR_UDID" screenshot /tmp/trinket-screen.png --type=png --mask=ignored
xcrun simctl io "$SIMULATOR_UDID" recordVideo /tmp/trinket-motion.mp4
```

Stop recording with SIGINT to the recording process. Use the managed shutdown
helper for recovery; it owns graceful guest-service teardown.

Accessibility Inspector is an optional diagnostic when investigating missing
accessibility content. An empty tree alone does not establish an app regression.
If needed, open the inspector through Computer Use, select the leased simulator,
and verify a known app control; selecting all processes can preserve the
inspection connection across app relaunches.
