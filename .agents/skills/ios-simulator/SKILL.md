---
name: ios-simulator
description: Launch, inspect, capture, or debug Trinket on iOS Simulator using the managed agent lease. Use before simctl operations or simulator UI verification.
---

# Simulator inspection

Use [SimulatorOperations.md](../../../Docs/Platform/SimulatorOperations.md) for
lease lifecycle, capture, recovery, and Xcode setup. For a normal agent launch:

```bash
./Scripts/run-simulator.sh --isolate
```

For screenshots, video, or UI interaction after launch, keep a parent lease alive
for the whole inspection as described in that guide. A booted device, a printed
UDID, or an explicit `--agent N` selects a device; none proves you hold its lease.
Never choose a fixed agent slot merely because it appears idle.

Target the leased UDID explicitly, never `booted`. Manage only your leased device;
never use `shutdown all`, `erase all`, or terminate foreign Xcode/Simulator processes.
Let the managed helpers perform recovery and graceful shutdown.

A screenshot can verify layout; exercise the interaction to verify behavior.
Report device/build identity and what was actually checked. Treat simulator
performance and absent physical haptics as limits of that evidence. On failure,
use [CI diagnostics](../../../Docs/AgentContext/ci-diagnostics.md) before retrying.
