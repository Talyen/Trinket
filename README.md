# Trinket

Portrait-first **iOS 26+** native fantasy idle auto-battler. Built with **Swift 6**, **SwiftUI**, and **SwiftData** using Apple's 2026 platform APIs. Requires **Xcode 26+**.

## Requirements

- Xcode 26+ with iOS 26 simulator runtime
- Swift 6.0
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- SwiftLint and SwiftFormat (pinned via `./Scripts/ensure-ci-tools.sh`; versions in `Scripts/tool-versions.env`)
- Ripgrep (`brew install ripgrep`) for `./Scripts/check-module-boundaries.sh`
- Python 3 (content codegen)

## Setup

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
brew install xcodegen ripgrep
./Scripts/ensure-ci-tools.sh   # installs pinned SwiftFormat + SwiftLint into .tools/
```

Enable git hooks (commit-msg advisory + pre-push format/generate gate):

```sh
git config core.hooksPath .githooks
```

Skip the pre-push gate once with `SKIP_TRINKET_PREPUSH=1 git push` when needed.

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
./Scripts/build.sh                 # compile into .DerivedData (shared with test.sh)
./Scripts/build-for-testing.sh && ./Scripts/test.sh unit --no-build
                                   # preferred full-unit path (mirrors CI: build once, test many)
./Scripts/test.sh unit             # TrinketTests + all package test schemes
./Scripts/test-package.sh TrinketDesignSystem  # one package scheme from its package dir
./Scripts/test.sh smoke            # local UI canary (Homestead, QuickSmoke)
./Scripts/test.sh smoke-full       # full Smoke.xctestplan (CI / PR)
./Scripts/test-iterate.sh SmokePlayTests   # build once, run one smoke class
./Scripts/test.sh style            # format + lint + UI style check
./Scripts/ci-gate.sh               # fast gate: generate, assert, boundaries, style
./Scripts/ci-locally.sh            # pre-push: gate + unit + quick smoke
./Scripts/test-deploy.sh           # pre-merge: generate, style, unit, full UI
./Scripts/run-simulator.sh
./Scripts/release.sh --dry-run     # preview changelog + App Store notes (no tests)
./Scripts/release.sh               # cut a release (runs test-deploy.sh unless --skip-tests)
```

Agent workflow: `AGENTS.md`. Test conventions: `Docs/Testing.md`.

## Docs

Start with **`Docs/Architecture.md`** for the repo map, module ownership, and tab/code mapping.

- Agent workflow: `AGENTS.md`
- Testing conventions: `Docs/Testing.md`
- UI test launch args / speed: `TrinketUITests/README.md`
- Product tabs / repo map: `Docs/Architecture.md`
- Content pipeline: `ContentManifest/README.md`
- Art pipeline: `ArtManifest/README.md`
- Music pipeline: `MusicManifest/README.md`
- Design system / chrome: `Packages/TrinketDesignSystem/README.md`
- Apple platform notes: `Docs/Platform/iOS26AppleReference.md`
- Fluid motion (SwiftUI): `Docs/AgentMotion.md`
- CloudKit pre-ship checklist: `Docs/Platform/CloudKitPreShipChecklist.md`
- Release pipeline: `Scripts/README.md`
