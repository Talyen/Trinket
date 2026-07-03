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
./Scripts/generate.sh          # validate manifests, codegen, XcodeGen
./Scripts/build.sh
./Scripts/test.sh unit
./Scripts/test.sh smoke
./Scripts/run-simulator.sh
```

## Docs

- Architecture and module plan: `Docs/Architecture.md`
- Agent workflow: `AGENTS.md`
- Core design concepts: `Docs/CoreDesignConcepts.md`
- Content pipeline: `Docs/ContentPipeline.md`
- Art pipeline: `Docs/ArtPipeline.md`
- Music pipeline: `Docs/MusicPipeline.md`
- Apple-native guidance: `Docs/AppleNativeGuidelines.md`
- CloudKit pre-ship checklist: `Docs/CloudKitPreShipChecklist.md`
