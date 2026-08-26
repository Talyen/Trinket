---
name: ios-simulator
description: Use when inspecting, launching, controlling, capturing screenshots/video from, or debugging apps on the iOS Simulator, or when running xcrun simctl commands, managing simulator state, or verifying UI visually.
---

# iOS Simulator programmatic control

This skill guides programmatic interaction with the iOS Simulator using Apple's `xcrun simctl` CLI and repository-specific isolation protocols.

## Trinket isolation & safety rules

When working inside the Trinket repository, respect the managed agent pool defined in [`Docs/Platform/SimulatorOperations.md`](../../../Docs/Platform/SimulatorOperations.md):

- **Always target specific UDIDs**: Never use `booted` as a target alias because multiple simulators (`Trinket Run`, `Trinket Agent 1`, `Trinket Agent 2`) may run concurrently.
- **Never run destructive global commands**: Do not run `xcrun simctl shutdown all` or `xcrun simctl erase all`.
- **Use isolated slots**: For agent runs, use `--isolate` with repository runners (`./Scripts/run-simulator.sh` or `./Scripts/handoff.sh --isolate`). Agents lease an isolated slot (`Trinket Agent N`) to avoid interrupting user/human sessions (`Trinket Run`).
- **Never kill foreign simulator or Xcode processes**: Only manage the device leased to the current process.

---

## Quick command reference (`xcrun simctl`)

### 1. Device discovery & lifecycle

```bash
# Resolve UDID for a managed Trinket simulator
UDID="$(xcrun simctl list devices available -j | python3 Scripts/simctl_json.py udid-for-name "Trinket Run")"
# or for an agent slot:
UDID="$(xcrun simctl list devices available -j | python3 Scripts/simctl_json.py udid-for-name "Trinket Agent 1")"

# List available runtimes and devices in JSON format
xcrun simctl list devices available -j
xcrun simctl list runtimes -j

# Headless boot (sufficient for screenshotting, logs, and background testing)
xcrun simctl boot <UDID>
xcrun simctl bootstatus <UDID> -b

# Optional: Focus the Simulator GUI window (only when requested for visual inspection)
open -a Simulator --args -CurrentDeviceUDID <UDID>

# Safe graceful shutdown (stops PosterBoard first to prevent guest crash alerts)
xcrun simctl spawn <UDID> launchctl stop com.apple.PosterBoard 2>/dev/null || true
xcrun simctl shutdown <UDID>
```

### 2. App installation, launch & environment

```bash
# Prefer repo launcher to build, install, place on home screen, and run in dark mode
./Scripts/run-simulator.sh

# Manual install of a built app bundle
xcrun simctl install <UDID> /path/to/Trinket.app

# Launch app with dark mode and launch arguments
xcrun simctl launch --terminate-running-process <UDID> <bundle.identifier> -- -appearance dark

# Launch with environment variables
SIMCTL_CHILD_MY_FLAG=1 xcrun simctl launch <UDID> <bundle.identifier>

# Launch with locale/language override
xcrun simctl launch <UDID> <bundle.identifier> -- -AppleLanguages "(es)" -AppleLocale "es_ES"

# Terminate running app
xcrun simctl terminate <UDID> <bundle.identifier>

# Uninstall app (clears sandbox state)
xcrun simctl uninstall <UDID> <bundle.identifier>
```

### 3. Visual inspection & media capture

```bash
# Capture clean screenshot without window frame masking artifacts
xcrun simctl io <UDID> screenshot /path/to/screenshot.png --type=png --mask=ignored

# Record video of simulator screen (Ctrl+C / SIGINT to stop)
xcrun simctl io <UDID> recordVideo /path/to/recording.mp4

# Add photo or video to the simulator Photos library
xcrun simctl addmedia <UDID> /path/to/sample.png
```

### 4. UI appearance, Dynamic Type & environment overrides

```bash
# Switch appearance mode (Trinket defaults to dark)
xcrun simctl ui <UDID> appearance dark
xcrun simctl ui <UDID> appearance light

# Override Dynamic Type text size (for accessibility audits)
# Options: extra-small, small, medium, large, extra-large, extra-extra-large,
#          extra-extra-extra-large, accessibility-medium, accessibility-large, ...
xcrun simctl ui <UDID> content_size extra-large
xcrun simctl ui <UDID> content_size medium

# Increase contrast
xcrun simctl ui <UDID> increase_contrast enabled

# Override status bar for clean documentation / walkthrough visuals
xcrun simctl status_bar <UDID> override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularBars 4 \
  --wifiBars 3

# Clear status bar overrides
xcrun simctl status_bar <UDID> clear

# Open deep link / URL
xcrun simctl openurl <UDID> "trinket://route/path"

# Set/get clipboard content
echo "Hello World" | xcrun simctl pbcopy <UDID>
xcrun simctl pbpaste <UDID>
```

### 5. Sandbox data, user defaults & diagnostics

```bash
# Locate sandbox data container (save games, SwiftData / CoreData stores)
DATA_DIR="$(xcrun simctl get_app_container <UDID> <bundle.identifier> data)"
ls -la "$DATA_DIR/Documents/"

# Read / write UserDefaults within the guest simulator
xcrun simctl spawn <UDID> defaults read <bundle.identifier>
xcrun simctl spawn <UDID> defaults write <bundle.identifier> <key> -bool true

# Stream live unified logs filtered to app subsystem
xcrun simctl spawn <UDID> log stream --predicate 'subsystem == "<bundle.identifier>"' --level debug

# Grant or revoke permissions
xcrun simctl privacy <UDID> grant photos <bundle.identifier>
xcrun simctl privacy <UDID> reset all <bundle.identifier>

# Simulate an APNs push notification
xcrun simctl push <UDID> <bundle.identifier> payload.apns
```

---

## Recipes for agents

### Taking a clean visual screenshot for a walkthrough
1. Resolve target UDID:
   ```bash
   UDID="$(xcrun simctl list devices available -j | python3 Scripts/simctl_json.py udid-for-name "Trinket Run")"
   ```
2. Build and launch the app using `./Scripts/run-simulator.sh` or `xcrun simctl launch`.
3. Set standard visual state:
   ```bash
   xcrun simctl ui "$UDID" appearance dark
   xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100
   ```
4. Capture screenshot directly into your conversation artifacts directory:
   ```bash
   xcrun simctl io "$UDID" screenshot "<artifact_dir>/screenshot.png" --type=png --mask=ignored
   ```
5. Clean up status bar override:
   ```bash
   xcrun simctl status_bar "$UDID" clear
   ```
