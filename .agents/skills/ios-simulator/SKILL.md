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

Native interaction is lazy, so capture and Computer Use work without Xcode's
bridge. If native discovery fails, use Computer Use with the printed device UI
path and confirm the selected device. Do not create another native session beside
an uncertain one. The controller reports failures and retains a recovery record
when closure cannot be confirmed. Never start a separate Xcode session for a
controller-owned native inspection.

Inspect actual saved images and record screen/state and build provenance; command
success alone does not establish visual acceptance.

Managed scripts own builds, installs, leases and logs. Use native device tools or
Computer Use for exploratory input, and existing XCTest journeys for repeatable
checks under [Verification.md](../../../Docs/Platform/Verification.md#choosing-ui-verification).
After an unsuccessful tool action, inspect the current target/state and try one
relevant alternative. If both inspection routes are unavailable, report the exact
limitation. Do not invent an input driver or substitute test success for visual review.

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
