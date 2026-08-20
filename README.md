# Trinket

Portrait-first **iOS 26+** native fantasy turn-based card combat (deckbuilder). Built with **Swift 6**, **SwiftUI**, and **SwiftData** using Apple's 2026 platform APIs. Requires **Xcode 26+**.

## Requirements

- Xcode 26+ with iOS 26 simulator runtime
- Swift 6 language mode (SwiftPM manifests use tools version 6.2)
- Pinned XcodeGen, SwiftFormat, SwiftLint, ripgrep, and xcbeautify via `./Scripts/ensure-ci-tools.sh` (versions in `Scripts/tool-versions.env`)
- Python 3 (content codegen)

## Setup

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
./Scripts/ensure-ci-tools.sh   # pinned XcodeGen, ripgrep, xcbeautify, SwiftFormat, SwiftLint into .tools/
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

The complete command index and agent path-scoping rules live in
[Scripts/README.md](Scripts/README.md). Agent guardrails are in [AGENTS.md](AGENTS.md),
and test semantics are in [Testing.md](Docs/Platform/Testing.md).

## Docs

Map and source-of-truth table: [Docs/README.md](Docs/README.md).

- Repo map and module DAG: [Architecture.md](Docs/Platform/Architecture.md)
- Product decisions: [Decisions.md](Docs/Product/Decisions.md)
- Verification and testing: [Verification.md](Docs/Platform/Verification.md) and [Testing.md](Docs/Platform/Testing.md)
- Content and media: [content](ContentManifest/README.md), [art](ArtManifest/README.md), [music](MusicManifest/README.md), [sound](SoundManifest/README.md), and [cinematics](CinematicManifest/README.md)
- Design system: [TrinketDesignSystem](Packages/TrinketDesignSystem/README.md)
- Release: [Release.md](Docs/Platform/Release.md)
- Audits: [Audits](Docs/Audits/README.md)
