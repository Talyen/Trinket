# Trinket

Portrait-first **iOS 26+** native fantasy turn-based card combat (deckbuilder). Built with **Swift 6**, **SwiftUI**, and **SwiftData** using Apple's 2026 platform APIs. Requires **Xcode 26+**.

## Player loop

Choose a Journey, Labyrinth, Spire, or encounter from Play; bring a Hero and
Companion into three-card-hand combat; then carry rewards back into Collection
loadouts and Homestead upgrades. Collection owns the party's equipment and
talents, Homestead turns gathered resources into permanent progress, and Options
holds device preferences without gating play or progress behind an account.

## Start here

- **Humans:** setup below → `./Scripts/generate.sh` → `./Scripts/build.sh` → `./Scripts/run-simulator.sh`. Command details: [Scripts/README.md](Scripts/README.md).
- **Agents:** [AGENTS.md](AGENTS.md), then `./Scripts/agent-context.sh --agent --paths <changed-paths...>` for the required read contract. Test semantics: [Testing.md](Docs/Platform/Testing.md).
- **Designers:** player decisions in [Decisions.md](Docs/Product/Decisions.md), surfaces in [Overview.md](Docs/Product/Overview.md), visual direction in [ArtworkStyleGuide.md](Docs/Product/ArtworkStyleGuide.md).

## Requirements

- Xcode 26+ with iOS 26 simulator runtime (toolchain ladder: [Scripts/README.md](Scripts/README.md))
- Swift 6 language mode (SwiftPM manifests use tools version 6.2)
- Pinned XcodeGen, SwiftFormat, SwiftLint, ripgrep, and xcbeautify via `./Scripts/ensure-ci-tools.sh` (versions in `Scripts/tool-versions.env`)
- Python 3 (content codegen)

## Setup

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
./Scripts/ensure-ci-tools.sh   # pinned XcodeGen, ripgrep, xcbeautify, SwiftFormat, SwiftLint into .tools/
```

Enable git hooks (commit format and push discipline: [Release.md](Docs/Platform/Release.md)):

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
- Game surfaces: [Overview.md](Docs/Product/Overview.md) — Journey, Labyrinth, Spire, Collection, Homestead
- Release: [Release.md](Docs/Platform/Release.md)
- Audits: [Audits](Docs/Audits/README.md)
