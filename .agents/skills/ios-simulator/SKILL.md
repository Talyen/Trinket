---
name: ios-simulator
description: Launch, inspect, capture, or debug Trinket on iOS Simulator using a managed lease and Computer Use or native Xcode tools. Use before simulator operations or UI verification.
---

# Simulator inspection

For interactive inspection, start the managed launcher in a persistent terminal
and keep its session alive:

```bash
python3 /Users/ryanmcintire/Developer/.coordination/heavy_lane.py \
  --owner '<thread-id>' --wait 900 --timeout 300 -- \
  ./Scripts/run-simulator.sh --isolate --inspect
```

Replace `<thread-id>` with this chat's identifier. The outer `heavy_lane.py`
wrapper covers the full build, setup, and inspection window; see
[Verification](../../../Docs/Platform/Verification.md#confidence-ladder) for
authorization and admission limits.

Once `Inspection ready` prints, send commands to that same terminal's stdin:

- `status\n`: device/build target and available inspection routes.
- `capture\n`: screenshot plus product metadata saved in Deliverables.
- `native\n`: discover Xcode tools, start one native session for the leased
  UDID, and capture its screenshot and hierarchy (the controller retains the
  session key).
- `event <command>\n`: send an Xcode interaction command on that session and
  capture the result (see [device-interaction](../device-interaction/SKILL.md)
  and its input reference for syntax).
- `stop\n`: close the native session and release the lease cleanly.

## Safeguards and interaction tips

- **Lease isolation**: target only the exact leased UDID in `simctl` commands
  (never `booted`), and let the managed scripts handle shutdown and recovery
  ([Simulator operations](../../../Docs/Platform/SimulatorOperations.md#inspection-lease-and-capture)).
- **One native session**: prefer `native`/`event` when available; don't open a
  second native session alongside the controller's. See
  [native session recovery](../../../Docs/Platform/SimulatorOperations.md#native-session-recovery)
  if a start looks stuck.
- **Computer Use / Device Hub**: if native tools aren't available, use Computer
  Use against the printed device UI path, confirming the leased simulator is
  selected in Device Hub's sidebar (Xcode 27) or Simulator (older Xcode).
- **Repeatable checks and failures**: use existing XCTest journeys for
  repeatable flows ([Verification.md](../../../Docs/Platform/Verification.md#choosing-ui-verification))
  and [CI diagnostics](../../../Docs/AgentContext/ci-diagnostics.md) for
  build/test failures. Keep in mind that the simulator doesn't reflect real
  device performance or physical haptics.

## Launch options

Add `--unlocked` for fully unlocked gameplay (reseeds a separate dev save and
disables cloud sync; see
[Purchases](../../../Docs/Platform/Purchases.md#local-development)). App
arguments follow `--`:

```bash
./Scripts/run-simulator.sh --isolate --inspect --unlocked -- -launch-screen hero:wildcard
```

To pin an exact installed runtime, set both selectors before launch (exact
versions fail fast if missing rather than falling back; `TRINKET_SIM_OS_MAJOR`
picks the newest installed runtime in that major):

```bash
TRINKET_SIM_DEVICE_TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
TRINKET_SIM_OS_VERSION=27.0 ./Scripts/run-simulator.sh --isolate --inspect
```

## Evidence capture

The inspection terminal's `capture` command saves screenshots directly to
Deliverables. For video recording or a custom path, set `SIMULATOR_UDID` to the
leased UDID printed by the active session:

```bash
xcrun simctl io "$SIMULATOR_UDID" screenshot /tmp/trinket-screen.png --type=png --mask=ignored
xcrun simctl io "$SIMULATOR_UDID" recordVideo /tmp/trinket-motion.mp4
```

Stop `recordVideo` with SIGINT. If you're diagnosing missing accessibility
content, Accessibility Inspector can be pointed at the leased simulator
(selecting all processes helps preserve the connection across app relaunches).
