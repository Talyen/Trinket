# AGENTS.md

Guidance for Codex and other coding agents working on Trinket.

## Product Direction

Trinket is an iOS game learning project. The current product direction is a portrait-first fantasy idle auto-battler with heroes, pets, equipment, abilities, items, and long-term meta-progression.

Long-term goal: build an iOS game that can eventually ship through the App Store.

## Current Decisions

- Platform: iOS.
- Orientation: portrait-first and iPhone-first.
- UI stack: prefer Apple-native Swift, SwiftUI, SpriteKit, UIKit, Foundation, CoreGraphics, AVFoundation, GameKit, StoreKit, etc.
- Apple guidance: follow `Docs/AppleNativeGuidelines.md` and refresh against official Apple docs before major UI, privacy, monetization, accessibility, or App Store decisions.
- UX goal: smooth, native iOS feel over web-style UI patterns.
- Controls: primary game controls should live near the bottom of the screen for thumb reachability.
- Layout: respect safe areas, Dynamic Type where appropriate, and one-handed use.
- Project workflow: CLI-first and agent-friendly through XcodeGen and scripts.
- Xcode project: `project.yml` is the source of truth; regenerate `Trinket.xcodeproj` instead of manually editing project files.
- Core navigation: a native persistent bottom `TabView`.
- Top-level tabs: `Play`, `Heroes`, `Pets`, `Homestead`, `Options`.
- Default launch tab: `Play`.
- Card language: 3:4 full-art cards are the central representation for heroes, pets, abilities, items, and equipment.
- First battle skeleton: `Play -> Battle -> Select Hero -> Select Pet -> Battle`.
- Combat default: idle auto-battle. Hero and Pet alternate placeholder `Strike` abilities against a single enemy.
- Battle UI: keep the battlefield focused on Enemy, Hero, and Pet cards with health bars; show names, HP text, abilities, and logs through native sheets.
- Combat feedback: render ability feedback through a queued SwiftUI event overlay with stable event IDs, damage-type styling, icons, and Reduce Motion support.
- Health bars: use custom animated SwiftUI bars for game combat so damage and healing can show smooth fill/trail feedback while exact HP remains in accessibility and sheets.
- Card styling: use shared 12-point continuous rounded corners for card-like surfaces.
- Prototype status: the initial tap-target sample was intentionally removed after proving the harness.

## Architecture Preferences

- Keep early gameplay experiments simple and inspectable.
- Separate game rules/state from rendering when practical, so rules can be unit tested.
- Use SwiftUI for app shell, menus, settings, overlays, and simple prototypes.
- Use SpriteKit when gameplay needs a 2D scene loop, sprites, physics, particles, collision, or high-frequency animation; current combat feedback remains SwiftUI-only.
- Avoid introducing cross-platform engines until there is a clear reason.
- Keep top-level game areas as tabs; use `NavigationStack` back buttons only for drill-in detail screens within a tab.
- Prefer small types with clear ownership over broad manager objects.
- Add abstractions only after repeated behavior appears.

## UI And Game Feel

- Design the first screen as the playable `Play` tab, not a marketing page.
- Keep bottom controls reachable and visually stable.
- Avoid placing critical controls near the top unless they are secondary.
- Use native controls for non-game UI: `Button`, `NavigationStack`, sheets, menus, toggles, sliders, haptics, and system materials.
- Prefer native `TabView` for top-level navigation until there is a strong reason for custom game chrome.
- Prefer SF Symbols for system actions and navigation until custom art has a clear gameplay or brand purpose.
- Accessibility is part of the baseline: support readable text, accessible labels, non-color-only state, and VoiceOver-friendly structure.
- Use haptics and animation intentionally for feedback.
- Test on simulator sizes that represent small and large iPhones.

## Harness Commands

Run these from the repository root.

Generate the Xcode project:

```sh
./Scripts/generate.sh
```

Build:

```sh
./Scripts/build.sh
```

Test:

```sh
./Scripts/test.sh
```

Build, install, and launch in Simulator:

```sh
./Scripts/run-simulator.sh
```

## Verification Expectations

Before considering a code change complete:

- Run `./Scripts/test.sh` for logic changes.
- Run `./Scripts/build.sh` for UI/project/config changes.
- Run `./Scripts/run-simulator.sh` for user-visible changes when feasible.
- Capture a simulator screenshot for meaningful visual changes.
- For meaningful UI changes, compare the result against `Docs/AppleNativeGuidelines.md`.
- Keep generated build output and `.DerivedData/` out of Git.

## Swift/iOS Tooling Map

React/web habits have close Swift/iOS equivalents, but the tools are different.

- Formatting: use `swift-format` or SwiftFormat. Pick one before enforcing it in CI.
- Linting: use SwiftLint for style, correctness nits, and project conventions.
- Dependency cleanup: there is no exact `knip` equivalent. Prefer Xcode build warnings, SwiftLint unused rules, compiler unused warnings, and periodic manual dependency review.
- Unit tests: use XCTest for game state, rules, scoring, persistence, and services.
- UI tests: use XCUITest for native end-to-end flows. This is the closest iOS analogue to Playwright.
- Visual checks: use simulator screenshots through `xcrun simctl io ... screenshot`; add snapshot testing later if visual regressions become important.
- Project generation: use XcodeGen from `project.yml`, similar in spirit to keeping build config declarative.
- CI: use `xcodebuild` in GitHub Actions or Xcode Cloud once the project needs remote verification.
- Performance: use Instruments and Xcode diagnostics rather than browser devtools.

## Recommended Near-Term Tooling

Do not install every tool immediately. The current minimum useful harness is:

1. XcodeGen for project generation.
2. `xcodebuild` scripts for build/test/run.
3. XCTest for logic tests.

Next additions, when the app has more code:

1. SwiftLint with a small, non-fussy rule set.
2. A formatter, either `swift-format` or SwiftFormat.
3. XCUITest for smoke tests once navigation and menus exist.
4. Snapshot testing only after the visual design stabilizes.

## Git Hygiene

- Treat generated `Trinket.xcodeproj` as a generated artifact from `project.yml`.
- Do not commit `.DerivedData/`.
- Make small commits around working states.
- Prefer implementation plus verification over large speculative refactors.

## Open Product Questions

- What are the exact idle battle rules?
- Does the game need SpriteKit immediately, or can SwiftUI carry the first prototype?
- Will there be Game Center achievements, leaderboards, or local-only progress?
- How do heroes, pets, abilities, equipment, and homestead upgrades interact?
