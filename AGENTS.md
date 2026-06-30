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

- Scripts: `generate.sh`, `build.sh`, `test.sh`, `test-iterate.sh`, `test-deploy.sh`, `lint.sh`, `ci-locally.sh`, `run-simulator.sh`, `prepare-art-assets.sh`, `capture-screenshot.sh`, `./Scripts/test.sh style`.
- Test tiers: **smoke** (per-screen, deep-link, fast) → **targeted full-UI** (one `TestClass`/`testMethod`) → **full UI suite** (deploy gate). Don't reach past the tier you actually need.
- **UI iteration loop:** `./Scripts/test-iterate.sh`. With no args it runs smoke only. Pass `TestClass` or `TestClass/testMethod` (repeatable) to also run that targeted full-UI test, e.g. `./Scripts/test-iterate.sh SmokeCollectionTests Collection/TabNavigationUITests`. Add `--fast` to skip rebuild on re-runs.
- **Deploy gate:** `./Scripts/test-deploy.sh` (style + unit + smoke + full UI). Run pre-merge / nightly, not during local iteration. `ci-locally.sh` remains the fast pre-push lane (style + unit + smoke).
- Do NOT run the full UI suite (`./Scripts/test.sh ui` with no target) or `all` during local iteration. Use `test-iterate.sh` instead.
- For minor UI tweaks, `./Scripts/build.sh` or `./Scripts/run-simulator.sh` + a screenshot is often enough before any tests.
- After `project.yml`/target changes, run `./Scripts/generate.sh` before build/test.
- Visual changes: `./Scripts/run-simulator.sh`; screenshots are allowed when useful. Agents may use focused simulator/XCUITest navigation and screenshot checks without asking first. Prefer interactive harness (e.g., Computer Use) and XCUITest over manual tapping.
- Run `./Scripts/check-ui-style.sh` after UI styling changes.
- Deterministic battle testing: `BattleSimulator` in `Trinket/BattleModels.swift`.
- Run `./Scripts/ci-locally.sh` before pushing; keep generated build output and `.DerivedData/` out of Git.
- Never hand-edit `.swiftlint.yml` rule severity without a project-wide reason noted here.

## UI Test Conventions

- New smoke tests go in `TrinketUITests/Smoke/`. Use `TestLaunchArg.allForScreen(...)` deep links (see `Trinket/App/AppEnvironment.swift:36`) to launch directly into the screen under test: `hero:<id>`, `pet:<id>`, `item:<id>`, `options`, `battle`. This skips tab-tap + animation waits and keeps smoke fast.
- Full-UI multi-step flows go in `TrinketUITests/{Collection,Battle,Search}/` and walk the navigation explicitly. Reserve them for the deploy tier; they are not for iteration.
- One assertion focus per test method. If a smoke test grows past ~20 lines or starts scrolling, split it.

Harness: XcodeGen, `xcodebuild` scripts, XCTest, early XCUITest, SwiftLint, `check-ui-style.sh`.
