# Trinket

Portrait-first **iOS 26+** native fantasy turn-based card combat (deckbuilder). Built with **SwiftUI** and **SwiftData**. See the build requirements below.

## Player loop

Choose Campaign or Explore from Play; bring a Hero and
Companion into three-card-hand combat; then carry rewards back into Collection
loadouts and Homestead upgrades. Collection owns the party's equipment and
talents, Homestead turns gathered resources into permanent progress, and Options
holds device preferences without gating play or progress behind an account.

## Start here

- **Humans:** setup below → `./Scripts/generate.sh` → `./Scripts/build.sh` → `./Scripts/run-simulator.sh`. Command details: [Scripts/README.md](Scripts/README.md).
- **Agents:** [AGENTS.md](AGENTS.md), then `./Scripts/agent-context.sh --agent --paths <changed-paths...>` for safeguards, ownership constraints, and relevant behavior references. Test semantics: [Testing.md](Docs/Platform/Testing.md).
- **Designers:** player decisions in [Decisions.md](Docs/Product/Decisions.md), surfaces in [Overview.md](Docs/Product/Overview.md), visual direction in [ArtworkStyleGuide.md](Docs/Product/ArtworkStyleGuide.md).

## Requirements

- Xcode 27+ with Swift 6.4+ and an installed supported iOS simulator runtime
- Swift 6 language mode; package toolchain minimums live in `Packages/*/Package.swift`
- [Platform support](Docs/Platform/ApplePlatformReference.md#platform-support) distinguishes the iOS deployment target from the build toolchain; [toolchain selection](Scripts/Reference.md#toolchain-ladder) explains local and CI selection
- Pinned XcodeGen, SwiftFormat, SwiftLint, ripgrep, and xcbeautify via `./Scripts/ensure-ci-tools.sh` (versions in `Scripts/tool-versions.env`)
- Python 3 (content codegen)

## Setup

Select the installed Xcode for this shell (substitute its actual path):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
sudo env DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild -runFirstLaunch
./Scripts/ensure-ci-tools.sh   # pinned XcodeGen, ripgrep, xcbeautify, SwiftFormat, SwiftLint into .tools/
```

Enable git hooks (commit format and push discipline: [Release.md](Docs/Platform/Release.md)):

```sh
git config core.hooksPath .githooks
```

## First Run

```sh
./Scripts/generate.sh    # validate manifests, generate content and the Xcode project
./Scripts/build.sh
./Scripts/run-simulator.sh
```

For content, art, music, SFX, or cinematic edits:

```sh
./Scripts/generate.sh --assets
```

## Docs

Map and source-of-truth table: [Docs/README.md](Docs/README.md).

- Repo map and module DAG: [Architecture.md](Docs/Platform/Architecture.md)
- Product decisions: [Decisions.md](Docs/Product/Decisions.md)
- Verification and testing: [Verification.md](Docs/Platform/Verification.md) and [Testing.md](Docs/Platform/Testing.md)
- Content and media: [content](ContentManifest/README.md), [art](ArtManifest/README.md), [music](MusicManifest/README.md), [sound](SoundManifest/README.md), and [cinematics](CinematicManifest/README.md)
- Design system: [TrinketDesignSystem](Packages/TrinketDesignSystem/README.md)
- Game surfaces: [Overview.md](Docs/Product/Overview.md) — Campaign, Explore, Collection, Homestead
- Release: [Release.md](Docs/Platform/Release.md)
- Audits: [Audits](Docs/Audits/README.md)
