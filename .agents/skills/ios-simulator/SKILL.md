---
name: ios-simulator
description: Launch, inspect, capture, or debug Trinket on iOS Simulator using a managed lease and Computer Use or native Xcode tools. Use before simulator operations or UI verification.
---

# Simulator inspection

For interactive inspection, run this in a persistent terminal (`exec_command`
with `tty=true`), and retain the returned session ID:

```bash
./Scripts/run-simulator.sh --isolate --inspect
```

Wait for `Inspection ready`. The same terminal owns the leased device, captures,
and optional native Xcode session. Keep it alive and send these commands through
`write_stdin`:

- `status\n`: device/build target and available inspection routes.
- `capture\n`: screenshot plus product metadata saved in Deliverables.
- `native\n`: discover Xcode tools, start one native session for the leased UDID,
  and capture its screenshot and hierarchy. The controller retains the session key.
- `event <command>\n`: use the documented Xcode interaction command on that same
  session, then capture the result. Read the [native interaction guidance](../device-interaction/SKILL.md)
  before input, choose positions from the latest hierarchy, and observe each result.
- `stop\n`: close the native session before releasing the lease; confirm exit.

Prefer native Xcode input when exposed; otherwise use Computer Use with the printed
device UI path. Native discovery is lazy. Never start a separate native session
beside the controller's session or an uncertain start; follow
[native session recovery](../../../Docs/Platform/SimulatorOperations.md#native-session-recovery).
The controller closes its native session before releasing the lease, including
on EOF or handled cancellation.

Inspect actual saved images and record screen/state and build provenance; command
success alone does not establish visual acceptance.

Managed scripts own builds, installs, leases and logs. Use native device tools or
Computer Use for exploratory input, and existing XCTest journeys for repeatable
checks under [Verification.md](../../../Docs/Platform/Verification.md#choosing-ui-verification).
[Simulator operations](../../../Docs/Platform/SimulatorOperations.md#inspection-lease-and-capture)
owns lease isolation, recovery and mirror policy. Target only the exact leased
UDID in simctl commands, never `booted`; managed helpers own shutdown and recovery.

Confirm the window's device name matches the launcher's leased simulator before
interacting; select the leased device in Device Hub's sidebar (or Simulator) if
another device is selected. An opened app alone does not prove device selection.
Recheck the target after a window change. Observe the current screen, act, and
inspect the resulting state before choosing the next action. Prefer available
controls, and use screenshot-based coordinate clicks or drags from the current
observation when accessibility controls are absent or ineffective. After an
unsuccessful action, refresh the observation, check the target window, overlays,
and control state, and try one relevant alternative. If the same obstacle
remains, use existing focused XCTest coverage or report the limitation. If neither
inspection route works, report the exact prerequisite. Do not write a custom input
driver or substitute test success for visual review.

## Launch options

For fully unlocked gameplay, add `--unlocked`. It reseeds a separate development
save and disables cloud sync; [Purchases](../../../Docs/Platform/Purchases.md#local-development)
owns the fixture and its distinct StoreKit test path. App arguments follow `--`:

```bash
./Scripts/run-simulator.sh --isolate --inspect --unlocked -- -launch-screen hero:wildcard
```

For an exact installed runtime, set both selectors before launch:

```bash
TRINKET_SIM_DEVICE_TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
TRINKET_SIM_OS_VERSION=27.0 ./Scripts/run-simulator.sh --isolate --inspect
```

Exact versions never fall back to a newer minor release; missing/incompatible
profiles fail before replacing the leased simulator. `TRINKET_SIM_OS_MAJOR` selects
the newest installed runtime in that major; both version selectors must agree
when supplied together. Xcode 27 opens Device Hub; older Xcode opens Simulator.

## Interaction evidence

A screenshot can verify layout; exercise the interaction to verify behavior.
Visual implementation tasks require saved final evidence and review under the
[visual completion gate](../../../Docs/Platform/Verification.md#visual-completion-gate);
routine diagnostic observations alone do not close them.
Report device/build identity and what was actually checked. Treat simulator
performance and absent physical haptics as limits of that evidence. Use
[CI diagnostics](../../../Docs/AgentContext/ci-diagnostics.md) for build/test
failures, and the recovery workflow above for unsuccessful UI actions.

## Evidence capture

The inspection terminal's `capture` command saves a screenshot without copying a
UDID or choosing a destination. For recording or another explicit destination,
set `SIMULATOR_UDID` to the UDID printed by the still-running inspection session:

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
