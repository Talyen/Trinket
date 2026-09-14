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
and operate the matching Simulator window. Follow the tool's live documentation;
its JavaScript calls are the supported interaction interface. Keep the terminal
session alive throughout inspection. Send `stop\n` to that session using
`write_stdin` when finished, and confirm the process exits.

Use managed scripts for building, installing, leases, and logs; Computer Use for
exploratory taps, drags, typing, and visual checks; existing XCTest journeys for
repeatable regression checks under [Verification.md](../../../Docs/Platform/Verification.md#choosing-ui-verification).
Do not invent AppleScript, Swift, or event-injection programs to operate the UI.
If Computer Use is unavailable, report that limitation and use an existing test
for the behavior it actually covers; do not claim interactive inspection.

[Simulator operations](../../../Docs/Platform/SimulatorOperations.md) owns window
selection, interaction recovery, optional evidence capture, and lease details.
A booted device or printed UDID does not prove a live lease. Never choose a fixed
agent slot merely because it appears idle. Target the leased UDID explicitly in
simctl commands, never `booted`; manage only your leased device and let the
managed helpers handle recovery and shutdown.

A screenshot can verify layout; exercise the interaction to verify behavior.
Report device/build identity and what was actually checked. Treat simulator
performance and absent physical haptics as limits of that evidence. Use
[CI diagnostics](../../../Docs/AgentContext/ci-diagnostics.md) for build/test
failures, and the simulator guide's interaction recovery for unsuccessful UI actions.
