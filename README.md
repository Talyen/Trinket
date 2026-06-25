# Trinket

A small SwiftUI iOS starter app set up for CLI-first development with Codex.

## Requirements

- Xcode installed at `/Applications/Xcode.app`
- Xcode command-line tools selected:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

- XcodeGen installed:

```sh
brew install xcodegen
```

## Harness Commands

Generate the Xcode project:

```sh
./Scripts/generate.sh
```

Build the app for the iPhone 17 simulator:

```sh
./Scripts/build.sh
```

Run tests:

```sh
./Scripts/test.sh
```

Build, install, and launch in Simulator:

```sh
./Scripts/run-simulator.sh
```

## Project Shape

- `project.yml` is the source of truth for the generated Xcode project.
- `Trinket/` contains the app code.
- `TrinketTests/` contains unit tests.
- `Scripts/` contains repeatable CLI workflows.
