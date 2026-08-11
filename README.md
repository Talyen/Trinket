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
./Scripts/generate.sh              # validate manifests, codegen, cached XcodeGen
./Scripts/build.sh                 # compile into .DerivedData (shared with test.sh)
./Scripts/build-for-testing.sh     # app + all package schemes for --no-build reuse
./Scripts/test.sh unit --no-build  # re-run all package schemes without rebuilding
./Scripts/test.sh unit             # all package test schemes in parallel
./Scripts/test-package.sh TrinketDesignSystem  # one package scheme, run from the repo root
./Scripts/test.sh smoke            # local UI canary (Homestead, QuickSmoke)
./Scripts/test.sh smoke-full       # full Smoke.xctestplan (CI / PR)
./Scripts/test-iterate.sh SmokePlayTests   # build once, run one smoke class
./Scripts/test.sh style            # format + lint + UI style check
./Scripts/ci-gate.sh               # generate/assert, boundaries, style, script regressions
./Scripts/handoff.sh --isolate --paths <changed-files>
                                   # fast local path-scoped verification
./Scripts/test-deploy.sh --mode smoke   # optional full local confidence: gate + unit + quick smoke
./Scripts/test-deploy.sh           # explicit release/pre-merge confidence: unit + full UI
./Scripts/run-simulator.sh
./Scripts/release.sh --dry-run     # preview changelog + App Store notes (no tests)
./Scripts/release.sh               # cut a release (runs test-deploy.sh unless --skip-tests)
```

Agent workflow: [AGENTS.md](AGENTS.md). Test conventions:
[Testing.md](Docs/Platform/Testing.md). CI fixer bot:
[CI-FIXER.md](Docs/CI-FIXER.md).

## Docs

Start with [Architecture.md](Docs/Platform/Architecture.md) for the repo map,
module ownership, and tab/code mapping.

- Product decisions: [Decisions.md](Docs/Product/Decisions.md)
- Verification and testing: [Verification.md](Docs/Platform/Verification.md) and [Testing.md](Docs/Platform/Testing.md)
- Product tabs and module map: [Architecture.md](Docs/Platform/Architecture.md)
- Content and media: [content](ContentManifest/README.md), [art](ArtManifest/README.md), [music](MusicManifest/README.md), [sound](SoundManifest/README.md), and [cinematics](CinematicManifest/README.md)
- Design system and motion: [TrinketDesignSystem](Packages/TrinketDesignSystem/README.md)
- Apple platform guidance: [iOS reference](Docs/Platform/iOS26AppleReference.md), [CloudKit checklist](Docs/Platform/CloudKitPreShipChecklist.md), and [identity plan](Docs/Platform/IdentityPlan.md)
- Performance: [frame pacing](Docs/Platform/PerformanceInvestigationPlaybook.md) and [memory/energy](Docs/Platform/MemoryAndEnergyInvestigation.md)
- Release process: [Release.md](Docs/Platform/Release.md)
- Re-runnable audits: [Audits](Docs/Audits/README.md)
