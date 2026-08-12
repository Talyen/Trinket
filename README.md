# Trinket

Portrait-first **iOS 26+** native fantasy turn-based card combat (deckbuilder). Built with **Swift 6**, **SwiftUI**, and **SwiftData** using Apple's 2026 platform APIs. Requires **Xcode 26+**.

## Requirements

- Xcode 26+ with iOS 26 simulator runtime
- Swift 6 language mode (SwiftPM manifests use tools version 6.2)
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
./Scripts/generate.sh    # validate manifests, codegen, cached XcodeGen — run before first build
./Scripts/build.sh
./Scripts/run-simulator.sh
```

For content, art, music, SFX, or cinematic edits:

```sh
./Scripts/generate.sh --assets
```

## Common Commands

```sh
./Scripts/generate.sh
./Scripts/generate.sh --assets
./Scripts/test-package.sh BattleEngine
./Scripts/test.sh unit
./Scripts/handoff.sh --isolate --paths <changed-files>
```

Full command index: [Scripts/README.md](Scripts/README.md). Agent workflow:
[AGENTS.md](AGENTS.md). Test conventions: [Testing.md](Docs/Platform/Testing.md).

## Docs

Map and source-of-truth table: [Docs/README.md](Docs/README.md).

- Repo map and module DAG: [Architecture.md](Docs/Platform/Architecture.md)
- Product decisions: [Decisions.md](Docs/Product/Decisions.md)
- Verification and testing: [Verification.md](Docs/Platform/Verification.md) and [Testing.md](Docs/Platform/Testing.md)
- Content and media: [content](ContentManifest/README.md), [art](ArtManifest/README.md), [music](MusicManifest/README.md), [sound](SoundManifest/README.md), and [cinematics](CinematicManifest/README.md)
- Design system: [TrinketDesignSystem](Packages/TrinketDesignSystem/README.md)
- Release: [Release.md](Docs/Platform/Release.md)
- Audits: [Audits](Docs/Audits/README.md)
