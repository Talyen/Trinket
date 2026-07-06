# Trinket

Portrait-first native iOS fantasy idle auto-battler.

## Requirements

- Xcode 26+ with iOS 26 simulator runtime
- Swift 6.0
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- SwiftLint and SwiftFormat (`brew install swiftlint swiftformat`)
- Ripgrep (`brew install ripgrep`) for `./Scripts/check-module-boundaries.sh`
- Python 3 (content codegen)

## Setup

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
brew install xcodegen swiftlint swiftformat ripgrep
```

Optional commit-message hook (advisory warnings):

```sh
git config core.hooksPath .githooks
```

## First Run

```sh
./Scripts/generate.sh    # validate manifests, codegen, XcodeGen — run before first build
./Scripts/build.sh
./Scripts/run-simulator.sh
```

For manifest, art, music, or SFX edits:

```sh
./Scripts/generate.sh --assets
```

## Common Commands

```sh
./Scripts/generate.sh              # validate manifests, codegen, XcodeGen
./Scripts/build.sh
./Scripts/test.sh unit             # TrinketTests + all package test schemes
./Scripts/test-package.sh TrinketDesignSystem  # one package scheme from its package dir
./Scripts/test.sh smoke            # UI smoke (~2 min)
./Scripts/test-iterate.sh SmokePlayTests   # build once, run one smoke class
./Scripts/test.sh style            # format + lint + UI style check
./Scripts/ci-locally.sh            # pre-push: generate, boundaries, style, unit, smoke
./Scripts/test-deploy.sh           # pre-merge: generate, style, unit, full UI
./Scripts/run-simulator.sh
./Scripts/release.sh --dry-run     # preview changelog + App Store notes (no tests)
./Scripts/release.sh               # cut a release (runs test-deploy.sh unless --skip-tests)
```

Agent workflow and test conventions: `AGENTS.md`.

## Docs

Start with **`Docs/Architecture.md`** for the repo map, module ownership, and tab/code mapping.

- Agent workflow: `AGENTS.md`
- Core design concepts: `Docs/Design/CoreDesignConcepts.md`
- Product roadmap (scratch ideas): `Docs/Roadmap.md`
- Content pipeline: `ContentManifest/README.md`
- Art pipeline: `ArtManifest/README.md`
- Music pipeline: `MusicManifest/README.md`
- Apple-native guidance: `Docs/Design/AppleNativeGuidelines.md`
- CloudKit pre-ship checklist: `Docs/Audits/CloudKitPreShipChecklist.md`
- Release pipeline: `Scripts/README.md`
