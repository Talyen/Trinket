---
name: ios-device
description: Build, install, or debug Trinket on a physical iOS device. Use when asked to deploy to a real iPhone or test on hardware.
---

# Physical device deployment

Run the single command:

```bash
./Scripts/install-device.sh
```

This auto-detects the first paired physical device, builds with code signing,
installs via `xcrun devicectl`, and launches the app. Use `--device <name|id>`
to target a specific device, `--no-launch` to install without launching, and
`--verbose` to see xcodebuild output.

Prerequisites: a physical iPhone connected (USB or local network), paired with
this Mac, with Developer Mode enabled. The `DEVELOPMENT_TEAM` in `project.yml`
and the Xcode-managed provisioning profile handle signing automatically.

For simulator deployments, use the [ios-simulator](../ios-simulator/SKILL.md)
skill instead.
