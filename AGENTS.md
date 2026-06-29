# AGENTS.md

Guidance for agents on Trinket: portrait-first iOS fantasy idle auto-battler.

## Product & Architecture

- iOS iPhone-first, portrait. Apple-native Swift/SwiftUI/SpriteKit/UIKit/Foundation/CoreGraphics/AVFoundation/GameKit/StoreKit. Target: iOS 26.0, Swift 5.0.
- `Trinket/Generated/*` is generated — regenerate via `./Scripts/prepare-art-assets.sh`. `Raw Assets/` is the source library, excluded from the Xcode target.
- Simple experiments; rules/state separate from rendering; small owned types; abstract after repetition.
- SwiftUI for shell, menus, settings, overlays, prototypes. SpriteKit for 2D loops, sprites, physics, particles, collision, high-frequency animation.
- Native SwiftUI/Apple UI/UX; minimize customization to use defaults.

## Commands & Verification

- Scripts: `generate.sh`, `build.sh`, `test.sh`, `lint.sh`, `ci-locally.sh`, `run-simulator.sh`, `prepare-art-assets.sh`, `capture-screenshot.sh`, `./Scripts/test.sh style`.
- Do NOT run `./Scripts/test.sh ui` or `all` unless explicitly requested. Default to `./Scripts/test.sh`; use `./Scripts/build.sh` for minor UI tweaks.
- After `project.yml`/target changes, run `./Scripts/generate.sh` before build/test.
- Visual changes: `./Scripts/run-simulator.sh`; screenshots only when useful. Prefer interactive harness (e.g., Computer Use) and XCUITest over manual tapping.
- Deterministic battle testing: `BattleSimulator` in `Trinket/BattleModels.swift`.
- Run `./Scripts/ci-locally.sh` before pushing; keep generated build output and `.DerivedData/` out of Git.
- Never hand-edit `.swiftlint.yml` rule severity without a project-wide reason noted here.

Harness: XcodeGen, `xcodebuild` scripts, XCTest, early XCUITest, SwiftLint, `check-ui-style.sh`.
