---
name: ios-simulator
description: Use when inspecting, launching, controlling, capturing screenshots/video from, or debugging apps on the iOS Simulator, or when running xcrun simctl commands, managing simulator state, or verifying UI visually.
---

# iOS Simulator — isolation and capture

Executable isolation rules for `xcrun simctl` work. Full command catalog lives in `Docs/Platform/SimulatorOperations.md`.

## Rules

- **Target UDID, never `booted`** — multiple simulators (`Trinket Run`, `Trinket Agent 1/2`) run concurrently.
- **Never `shutdown all` / `erase all`** — only manage your leased device.
- **Use isolate slots**: `./Scripts/run-simulator.sh` or `./Scripts/handoff.sh --isolate` leases `Trinket Agent N`.
- **Never kill foreign Xcode/Simulator processes.**
- Graceful shutdown: `xcrun simctl spawn <UDID> launchctl stop com.apple.PosterBoard` before `shutdown`.

## Minimal commands

```bash
UDID="$(xcrun simctl list devices available -j | python3 Scripts/simctl_json.py udid-for-name "Trinket Agent 1")"
xcrun simctl boot <UDID> && xcrun simctl bootstatus <UDID> -b
./Scripts/run-simulator.sh                          # build + install + launch (dark)
xcrun simctl io <UDID> screenshot out.png --type=png --mask=ignored
xcrun simctl io <UDID> recordVideo out.mp4          # SIGINT to stop
xcrun simctl ui <UDID> appearance dark
xcrun simctl status_bar <UDID> override --time "9:41" --batteryState charged --batteryLevel 100
```

See `SimulatorOperations.md` for lifecycle, install/launch flags, `addmedia`, `pbcopy`, UserDefaults, `log stream`, and `privacy` details.
