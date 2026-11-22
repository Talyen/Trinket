---
name: ios-device
description: Build, install, debug, or profile Trinket on a physical iOS device. Use for real iPhone or iPad deployment, hardware diagnostics, and Instruments performance measurements over USB or Wi-Fi.
---

# Physical device deployment and profiling

See [Verification](../../../Docs/Platform/Verification.md#confidence-ladder) for
local authorization and host admission. Wrap the outer build/install or
profiling command once with `heavy_lane.py` (nested builds reuse that
admission), replacing `<thread-id>` with this chat's identifier.

## Build and install

Select the physical device explicitly under
[device-interaction](../device-interaction/SKILL.md#session-ownership), then
run:

```bash
python3 /Users/ryanmcintire/Developer/.coordination/heavy_lane.py \
  --owner '<thread-id>' --wait 900 --timeout 300 -- \
  ./Scripts/install-device.sh --device '<name|id>'
```

The script builds with code signing, installs via `xcrun devicectl`, and
launches the app. Pass `--no-launch` to install without launching and
`--verbose` for full `xcodebuild` output.

Prerequisites: a physical iPhone or iPad connected via USB or local network,
paired with this Mac, with Developer Mode enabled. `DEVELOPMENT_TEAM` in
`project.yml` and Xcode-managed profiles handle signing automatically. If the
app is already installed, you can inspect device evidence first and only rebuild
when needed.

## CPU and hitch profiling

For physical-device CPU and hitch measurements, prefer the repository's
validated wrapper—manual attachment and device-wide recording have known
failures on this setup:

```bash
python3 /Users/ryanmcintire/Developer/.coordination/heavy_lane.py \
  --owner '<thread-id>' --wait 900 --timeout 300 -- \
  python3 Scripts/profile-device.py --device '<physical UDID>' --build --duration 30
```

See the [physical-device profiling workflow](../../../Docs/Platform/PerformanceInvestigationPlaybook.md#physical-device-profiling-over-wi-fi)
for installed-app reuse, existing Release builds, symbol preparation, trace
validation, and connection troubleshooting.

For simulator deployments, use [ios-simulator](../ios-simulator/SKILL.md).
