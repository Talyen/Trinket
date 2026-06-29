# AGENTS.md

Guidance for agents on Trinket: portrait-first iOS fantasy idle auto-battler.

## Product & Architecture

- iOS iPhone-first, portrait. Apple-native Swift/SwiftUI/SpriteKit/UIKit/Foundation/CoreGraphics/AVFoundation/GameKit/StoreKit. Target: iOS 26.0, Swift 5.0.
- `Trinket/Generated/*` is generated — regenerate via `./Scripts/prepare-art-assets.sh`. `Raw Assets/` is the source library, excluded from the Xcode target.
- Simple experiments; rules/state separate from rendering; small owned types; abstract after repetition.
- SwiftUI for shell, menus, settings, overlays, prototypes. SpriteKit for 2D loops, sprites, physics, particles, collision, high-frequency animation.
- Native SwiftUI/Apple UI/UX; minimize customization to use defaults.

## Apple-Native Product Rules

- Prefer system SwiftUI controls, native navigation, SF Symbols, Dynamic Type, accessibility, safe areas, haptics, platform typography, and semantic colors/materials before custom game chrome.
- Use `TabView` only for top-level destinations. Use `NavigationStack`, sheets, alerts, menus, `ToolbarItem`, and in-content controls for detail flows and contextual actions.
- Keep portrait layouts thumb-reachable and assistive-tech friendly: respect VoiceOver, Reduce Motion, contrast, legibility, and Dynamic Type from the start.
- Route recurring chrome through `TrinketDesign`; avoid one-off raw `.buttonStyle`, material backgrounds, custom capsules/circles, selected-button states, fixed button-label frames, and simulated glass. Use `UIStyleCheck: allow` only for intentional exceptions.
- Use native glass only for floating controls/light app chrome on iOS 26+, with readable material fallbacks. Keep game content, cards, stat panels, and debug tools inspectable.
- Use `Toggle` for persistent modes and `Button` for one-shot actions. Prefer `controlSize`, `buttonBorderShape`, `Label`, SF Symbols, and semantic styles over visual size hacks.
- StoreKit, GameKit, privacy, tracking, accounts, analytics, ads, cloud, multiplayer, or external SDK work must use public Apple APIs and update docs with App Store/privacy implications.
- Follow Swift API Design Guidelines; clarity at call sites beats clever brevity. Keep models, rules, rendering, persistence, and platform services separated enough to test.
- For major UI work, check `Docs/AppleNativeGuidelines.md` and the relevant official Apple page before implementing.

## Commands & Verification

- Scripts: `generate.sh`, `build.sh`, `test.sh`, `lint.sh`, `ci-locally.sh`, `run-simulator.sh`, `prepare-art-assets.sh`, `capture-screenshot.sh`, `./Scripts/test.sh style`.
- Do NOT run the full UI suite (`./Scripts/test.sh ui` with no target) or `all` unless explicitly requested. Default to `./Scripts/test.sh`; use `./Scripts/build.sh` for minor UI tweaks.
- Narrowly scoped UI tests are allowed when relevant, such as `./Scripts/test.sh ui SmokeCollectionTests/testHeroDetailOpens` or one specific XCUITest class/method. Prefer the smallest useful UI verification.
- After `project.yml`/target changes, run `./Scripts/generate.sh` before build/test.
- Visual changes: `./Scripts/run-simulator.sh`; screenshots are allowed when useful. Agents may use focused simulator/XCUITest navigation and screenshot checks without asking first. Prefer interactive harness (e.g., Computer Use) and XCUITest over manual tapping.
- Run `./Scripts/check-ui-style.sh` after UI styling changes.
- Deterministic battle testing: `BattleSimulator` in `Trinket/BattleModels.swift`.
- Run `./Scripts/ci-locally.sh` before pushing; keep generated build output and `.DerivedData/` out of Git.
- Never hand-edit `.swiftlint.yml` rule severity without a project-wide reason noted here.

Harness: XcodeGen, `xcodebuild` scripts, XCTest, early XCUITest, SwiftLint, `check-ui-style.sh`.
