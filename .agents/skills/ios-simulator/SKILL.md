---
name: ios-simulator
description: Use when inspecting, launching, controlling, capturing screenshots/video from, or debugging apps on the iOS Simulator, or when running xcrun simctl commands, managing simulator state, or verifying UI visually.
---

# iOS Simulator programmatic control

This skill guides programmatic interaction with the iOS Simulator using Apple's `xcrun simctl` CLI and repository-specific isolation protocols.

## Trinket isolation & safety rules

When working inside the Trinket repository, respect the managed agent pool defined in [`Docs/Platform/SimulatorOperations.md`](file:///Users/ryanmcintire/Documents/Trinket/Docs/Platform/SimulatorOperations.md):

- **Never run destructive global commands**: Do not run `xcrun simctl shutdown all` or `xcrun simctl erase all`.
- **Use isolated slots**: For agent runs, use `--isolate` with repository runners (`./Scripts/run-simulator.sh` or `./Scripts/handoff.sh --isolate`). Agents lease an isolated slot (`Trinket Agent N`) to avoid interrupting user/human sessions (`Trinket Run`).
- **Never kill foreign simulator or Xcode processes**: Only manage the device leased to the current process.

---

## Quick command reference (`xcrun simctl`)

All commands operate on either a target device UDID or device name alias (or `booted` if only one simulator is active).

### 1. Device discovery & lifecycle

```bash
# List available runtimes and booted/available devices (JSON format for scripting)
xcrun simctl list devices available -j
xcrun simctl list runtimes -j

# Boot a specific simulator
xcrun simctl boot <UDID>

# Wait for boot to finish completely
xcrun simctl bootstatus <UDID> -b

# Open the Simulator GUI window focused on the device
open -a Simulator --args -CurrentDeviceUDID <UDID>

# Gracefully shutdown a specific device
xcrun simctl shutdown <UDID>
```

### 2. App installation, launch & control

```bash
# Install an app bundle (.app built for iphonesimulator)
xcrun simctl install <UDID> /path/to/App.app

# Launch app by bundle identifier
xcrun simctl launch <UDID> <bundle.identifier>

# Terminate running app
xcrun simctl terminate <UDID> <bundle.identifier>

# Relaunch with clean restart and arguments
xcrun simctl launch --terminate-running-process <UDID> <bundle.identifier> -- -key value

# Uninstall app
xcrun simctl uninstall <UDID> <bundle.identifier>

# Locate the sandboxed app container or data directory
xcrun simctl get_app_container <UDID> <bundle.identifier> data
```

### 3. Visual inspection & media capture

```bash
# Capture screenshot (PNG)
xcrun simctl io <UDID> screenshot /path/to/screenshot.png --type=png

# Record video of simulator screen (Ctrl+C / SIGINT to stop)
xcrun simctl io <UDID> recordVideo /path/to/recording.mp4

# Add photo or video to the simulator Photos library
xcrun simctl addmedia <UDID> /path/to/sample.png
```

### 4. UI appearance & environment overrides

```bash
# Switch appearance mode (light / dark)
xcrun simctl ui <UDID> appearance dark
xcrun simctl ui <UDID> appearance light

# Override status bar for clean screenshots / marketing visuals
xcrun simctl status_bar <UDID> override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularBars 4 \
  --wifiBars 3

# Clear status bar overrides
xcrun simctl status_bar <UDID> clear

# Open deep link / URL
xcrun simctl openurl <UDID> "my-scheme://route/path"

# Set/get clipboard content
echo "Hello World" | xcrun simctl pbcopy <UDID>
xcrun simctl pbpaste <UDID>
```

### 5. Permissions & privacy management

```bash
# Grant specific permission (e.g. photos, camera, location, notifications)
xcrun simctl privacy <UDID> grant photos <bundle.identifier>

# Revoke permission
xcrun simctl privacy <UDID> revoke location <bundle.identifier>

# Reset all permissions for an app
xcrun simctl privacy <UDID> reset all <bundle.identifier>
```

### 6. Push notifications & diagnostics

```bash
# Simulate an APNs push notification using a payload JSON file
xcrun simctl push <UDID> <bundle.identifier> payload.apns

# Stream live unified logs from the device filtered to app subsystem
xcrun simctl spawn <UDID> log stream --predicate 'subsystem == "<bundle.identifier>"' --level debug

# Collect diagnostic archive
xcrun simctl diagnose -b -o /path/to/output_dir
```

---

## Recipes for agents

### Taking a clean visual screenshot of a UI change
1. Ensure the app is built and installed on the designated simulator.
2. Override the status bar: `xcrun simctl status_bar <UDID> override --time "9:41" --batteryState charged --batteryLevel 100`.
3. Set appearance: `xcrun simctl ui <UDID> appearance dark`.
4. Launch app: `xcrun simctl launch --terminate-running-process <UDID> <bundle.identifier>`.
5. Wait briefly for view transitions / rendering to settle.
6. Capture: `xcrun simctl io <UDID> screenshot <artifact_path>.png`.
7. Clear status bar: `xcrun simctl status_bar <UDID> clear`.
