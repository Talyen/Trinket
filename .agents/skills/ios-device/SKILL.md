---
name: ios-device
description: Build, install, debug, or profile Trinket on a physical iOS device. Use for real iPhone or iPad deployment, hardware diagnostics, and Instruments performance measurements over USB or Wi-Fi.
---

# Physical device deployment and profiling

The [verification policy](../../../Docs/Platform/Verification.md#confidence-ladder)
owns local authorization and host admission. Wrap the entire build/install or
profiling command once; nested builds reuse that admission. Replace `<thread-id>`
with this chat's identifier. Use the policy's bounded device exception only when
the investigation needs it.

## Build and install

Select the intended physical device under the
[targeting and session safeguards](../device-interaction/SKILL.md#session-ownership).
For a build and install on that device, run:

```bash
python3 /Users/ryanmcintire/Developer/.coordination/heavy_lane.py \
  --owner '<thread-id>' --wait 900 --timeout 300 -- \
  ./Scripts/install-device.sh --device '<name|id>'
```

The script builds with code signing, installs via `xcrun devicectl`, and launches
the app. Use `--no-launch` to install without launching and `--verbose` to see
xcodebuild output.

Prerequisites: a physical iPhone or iPad connected (USB or local network), paired with
this Mac, with Developer Mode enabled. The `DEVELOPMENT_TEAM` in `project.yml`
and the Xcode-managed provisioning profile handle signing automatically.

For debugging an installed build, inspect the relevant device evidence first.
Rebuild and reinstall when the investigation needs an updated build.

## CPU and hitch profiling

For requested physical-device CPU and hitch measurements, default to the
repository's validated recording command:

```bash
python3 /Users/ryanmcintire/Developer/.coordination/heavy_lane.py \
  --owner '<thread-id>' --wait 900 --timeout 300 -- \
  python3 Scripts/profile-device.py --device '<physical UDID>' --build --duration 30
```

Read the [physical-device profiling workflow](../../../Docs/Platform/PerformanceInvestigationPlaybook.md#physical-device-profiling-over-wi-fi)
for installed-app reuse, existing Release builds, symbol preparation, evidence
validation, and connection failures. Use the wrapper before trying manual
attachment or device-wide recording; those paths have known failures on the
verified setup. A saved trace alone does not establish valid measurements.

For simulator deployments, use the [ios-simulator](../ios-simulator/SKILL.md)
skill instead.
