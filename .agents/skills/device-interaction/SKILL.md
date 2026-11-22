---
name: device-interaction
description: Inspect or operate Trinket on a managed simulator or explicitly selected physical device through Xcode's native MCP tools. Use for requested local UI verification or device diagnostics, including Computer Use failures; skip routine builds, unit tests, and logic-only edits.
---

# Native device interaction

Use Xcode's native device tools when an inspection needs screenshots, the
accessibility hierarchy, or device input. See the
[input reference](references/apple-device-interaction.md) for hierarchy format
and event syntax, and
[Verification](../../../Docs/Platform/Verification.md#local-simulator-budget)
for local inspection policy.

For managed simulators, use the [ios-simulator](../ios-simulator/SKILL.md)
controller's `native`/`event` commands—the controller owns that native session,
so avoid opening a second competing session with chat tools. The direct
procedure below is for physical devices or externally owned sessions.

## Session ownership

- **Target explicitly**: on a simulator, hold a managed lease under
  [Simulator operations](../../../Docs/Platform/SimulatorOperations.md#inspection-lease-and-capture)
  and pass the exact leased UDID (never a default or `booted` device). On
  physical hardware, select the device explicitly by name or identifier; use
  [ios-device](../ios-device/SKILL.md) for build/install and profiling.
- **Choose the right session tool**: inspect current tool metadata, then use
  `DeviceInteractionStartSession` for an already-installed app or
  `DeviceInteractionStartWorkspaceSession` when a workspace build/install is
  needed.
- **Per-run overrides**: for workspace launches, prefer `commandLineArguments`
  and `environmentVariables` over scheme edits (omit them to keep scheme
  defaults, or include `$(inherited)` when appending).
- **Clean up**: end the session with `DeviceInteractionEndSession` before
  releasing the lease or finishing up, including on errors, because the native
  runtime is expensive to leave open.

## Capture and input

Current Xcode exposes `DeviceInteractionSynthesize` (taking
`interactSessionKey`); check its tool metadata for supported events and
coordinate constraints.

Capture before acting so you have the current screenshot and hierarchy
`hitPoint` coordinates, then observe again after input to confirm the result.
When reporting findings, include the device/build identity, what you exercised,
and any limits (for example, screenshots verify layout rather than animation
feel, haptics, or hardware performance). If native tools aren't available, fall
back to Computer Use via [ios-simulator](../ios-simulator/SKILL.md) or note the
missing prerequisite.

## Apple source

The input reference is adapted from Apple's Xcode 27.0 export, build `27A266a`,
obtained on 2026-10-02 with `xcrun agent plugin path --plugin-format codex`.
The original export is retained in Git history at `cef5dd21c` under the same
reference path. Its subagent-only workflow, default-destination selection and
non-iOS examples are excluded from the operational adaptation.
On an Xcode update, export to a temporary location, compare relevant event semantics,
and refresh this skill/reference without replacing Trinket's session safeguards.
