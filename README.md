# Trinket

Portrait-first native iOS fantasy idle auto-battler.

## Setup

Requires Xcode and XcodeGen.

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
brew install xcodegen
```

## Common Commands

```sh
./Scripts/generate.sh
./Scripts/build.sh
./Scripts/test.sh
./Scripts/run-simulator.sh
./Scripts/run-debug-battle.sh Mage Drake
```

## Docs

- Agent workflow: `AGENTS.md`
- Core design concepts: `Docs/CoreDesignConcepts.md`
- Apple-native guidance: `Docs/AppleNativeGuidelines.md`
