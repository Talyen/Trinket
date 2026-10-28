---
name: device-interaction
description: Inspect or operate Trinket on a managed simulator or explicitly selected physical device through Xcode's native MCP tools. Use for requested local UI verification or device diagnostics, including Computer Use failures; skip routine builds, unit tests, and logic-only edits.
---

# Native device interaction

Use Xcode's device tools when the requested inspection needs screenshots,
accessibility hierarchy, or device input. Read the
[input reference](references/apple-device-interaction.md) before using those tools;
reuse it when already loaded and unchanged. This repository's
[verification policy](../../../Docs/Platform/Verification.md#local-simulator-budget)
owns local inspection and hosted qualification. Shipping-UI review uses the managed
inspection session described below; no additional approval is needed within that scope.

For managed simulators, follow the [simulator skill](../ios-simulator/SKILL.md)
for `native`/`event` commands and recovery. Its controller owns the native session;
do not create a second session with chat tools. Read the input reference for event
semantics and use the latest hierarchy.

The direct procedure below applies to physical devices or explicitly externally
owned native sessions.

## Session ownership

- For a simulator, hold a managed lease under
  [Simulator operations](../../../Docs/Platform/SimulatorOperations.md#inspection-lease-and-capture)
  throughout the native session. The
  [ios-simulator skill](../ios-simulator/SKILL.md) owns launch and lease technique.
  Use the exact leased UDID, never the current/default destination or an idle-looking
  booted device. An existing parent lease can support an already-installed-app
  diagnostic without rebuilding. Select physical hardware explicitly by name or
  identifier for builds, installs, profiling, and native input; do not rely on the
  first paired device or a tool's default destination. Use
  [ios-device](../ios-device/SKILL.md) for build/install and profiling commands.
- Read current tool metadata. Start `DeviceInteractionStartSession` for an
  already-installed app; use `DeviceInteractionStartWorkspaceSession` only when
  the task needs an authorized workspace build/install. Native session creation
  supplements a simulator lease; it does not replace it. Physical devices use
  explicit target selection, not a simulator lease. Build/install and profiling
  follow the host-admission workflow in [ios-device](../ios-device/SKILL.md).
- One agent operates each native session. Direct use is sufficient; delegation is
  optional when useful and authorized. If delegated, pass this skill, the session
  key, exact leased device and bounded task; the parent retains lease ownership.
- End the native session with `DeviceInteractionEndSession` before releasing the
  lease, including failed or cancelled checks. Do not leave a session open between
  unrelated tasks; its runtime is expensive.

For an explicitly requested workspace build/install, prefer the tool's per-run
`commandLineArguments` and `environmentVariables` over scheme edits. Omit them to
retain the scheme settings; `$(inherited)` preserves existing values when adding
arguments or environment entries. Inspect current metadata for their exact shape.

## Capture and input

Use the tools actually exposed in this chat: current Xcode names the capture/input
tool `DeviceInteractionSynthesize`, with `interactSessionKey`. Inspect its metadata
for supported events, arguments and coordinate constraints before use.

Capture with no interaction command first. Read the hierarchy and inspect the
screenshot before acting; prefer hierarchy hit points and observe again after
input. Follow the input reference's bounded retries and application activation
rules. Stay within the requested flow; do not edit code, rebuild, or reset saves
as an inspection workaround. The session owner closes the native session before
releasing its lease; a delegated operator reports evidence to that owner.

Report device/build identity, what was visible, which interactions were actually
exercised, and any missing evidence. Capturing SpringBoard does not verify Trinket.
Screenshots alone establish layout, not animation feel, physical haptics, or
hardware performance. If native tools are unavailable, use Computer Use under
the ios-simulator skill or report the missing prerequisite; do not invent an input
driver or substitute routine local test suites for interactive evidence.

## Apple source

The input reference is adapted from Apple's Xcode 27.0 export, build `27A266a`,
obtained on 2026-10-02 with `xcrun agent plugin path --plugin-format codex`.
The original export is retained in Git history at `cef5dd21c` under the same
reference path. Its subagent-only workflow, default-destination selection and
non-iOS examples are excluded from the operational adaptation.
On an Xcode update, export to a temporary location, compare relevant event semantics,
and refresh this skill/reference without replacing Trinket's session safeguards.
