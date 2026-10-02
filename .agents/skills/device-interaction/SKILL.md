---
name: device-interaction
description: Inspect or operate Trinket on a managed simulator or explicitly selected physical device through Xcode's native MCP tools. Use for requested local UI verification or device diagnostics, including Computer Use failures; skip routine builds, unit tests, and logic-only edits.
---

# Native device interaction

Use Xcode's device tools when the requested inspection needs screenshots,
accessibility hierarchy, or device input. Read the
[Apple workflow](references/apple-device-interaction.md) before using those tools;
reuse it when already loaded and unchanged. This repository's
[verification policy](../../../Docs/Platform/Verification.md#local-simulator-budget)
controls when local device work is authorized. Apple's automatic trigger after a
UI edit does not override Trinket's CI-owned verification policy.

## Main agent

- Hold a managed simulator lease under
  [Simulator operations](../../../Docs/Platform/SimulatorOperations.md#inspection-lease-and-capture)
  throughout the native session. The
  [ios-simulator skill](../ios-simulator/SKILL.md) owns launch and lease technique.
  Use the exact leased UDID, never the current/default destination or an idle-looking
  booted device. An existing parent lease can support an already-installed-app
  diagnostic without rebuilding. For physical hardware, follow
  [ios-device](../ios-device/SKILL.md) and select the intended device explicitly.
- Read current tool metadata. Start `DeviceInteractionStartSession` for an
  already-installed app; use `DeviceInteractionStartWorkspaceSession` only when
  the task needs a workspace build/install. Native session creation supplements
  the repository lease; it does not replace it.
- Delegate all native captures and input events to one subagent with exclusive use
  of that session. Give it this skill's path, the returned session key, exact
  device identity, and bounded verification task. The subagent must read this
  skill and the Apple reference itself. The main agent retains lease ownership.
- End the native session with `DeviceInteractionEndSession` before releasing the
  lease, including failed or cancelled checks. Do not leave a session open between
  unrelated tasks; its runtime is expensive.

## Device subagent

Use the tools actually exposed in this chat. Apple's snapshot calls the capture
tool `DeviceEventSynthesize`; the current Xcode tool is
`DeviceInteractionSynthesize`. Use its documented argument names, including
`interactSessionKey`, rather than inventing aliases from the reference. Current
tool constraints also govern supported events and coordinate selection when they
differ from Apple's snapshot.

Capture with no interaction command first. Read the hierarchy and inspect the
screenshot before acting; prefer hierarchy hit points and observe again after
input. Follow the Apple reference's bounded retries and application activation
rules. Stay within the requested flow; do not edit code, rebuild, or reset saves
as an inspection workaround. Report findings to the main agent and let it close
the session and release the lease.

Report device/build identity, what was visible, which interactions were actually
exercised, and any missing evidence. Capturing SpringBoard does not verify Trinket.
Screenshots alone establish layout, not animation feel, physical haptics, or
hardware performance. If native tools are unavailable, use Computer Use under
the ios-simulator skill or report the missing prerequisite; do not invent an input
driver or substitute routine local test suites for interactive evidence.

## Apple source

The reference is an unchanged export from Xcode 27.0, build `27A266a`, obtained on
2026-10-02 with `xcrun agent plugin path --plugin-format codex`. The command prints
the official plugin directory; its `skills/device-interaction/SKILL.md` is the
source. On an Xcode update, compare that source with the checked-in reference and
update the tool mapping and repository adaptation only where behavior changed.
