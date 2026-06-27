# AGENTS.md

Guidance for Codex and other agents on Trinket: a portrait-first native iOS fantasy idle auto-battler.

## Operating Rules

- Start code tasks with `git status --porcelain`; treat changes as in-flight user work.
- For non-trivial work, find docs with `rg --files -g '*.md'` and focused `rg <topic>`. Read `Docs/CoreDesignConcepts.md` for gameplay/progression/rewards and `Docs/AppleNativeGuidelines.md` for UI, accessibility, privacy, monetization, platform, or App Store choices.
- Start from an end-to-end-verifiable flow when possible. For bugs, reproduce with the closest practical automated or user-visible check first.
- Treat lint, test, and flake failures as harness problems.
- Push back when requests conflict with product direction, Apple guidance, or maintainability; explain the tradeoff and offer a stronger path.
- If an approach fails three times, stop, reassess with docs/logs/tests/Apple guidance, and ask for direction.
- Wrap up with changes, verification, and anything intentionally untouched.

## Product And Architecture

- iOS, iPhone-first, portrait-first; prefer Apple-native Swift, SwiftUI, SpriteKit, UIKit, Foundation, CoreGraphics, AVFoundation, GameKit, StoreKit.
- Persistent bottom `TabView`: `Play`, `Heroes`, `Pets`, `Homestead`, `Options`; launch to `Play`. Battle path: `Play -> Battle -> Select Hero -> Select Pet -> Battle`.
- Combat defaults to idle auto-battle: Hero and Pet alternate abilities against one enemy. Keywords: `Physical` direct damage, stacked `Burn` enemy damage-over-time.
- Keep experiments simple and inspectable; separate rules/state from rendering; prefer small owned types; add abstractions after repetition.
- Use SwiftUI for shell, menus, settings, overlays, prototypes. Use SpriteKit only for 2D loops, sprites, physics, particles, collision, or high-frequency animation.
- Keep UI native, accessible, and thumb-friendly: safe areas, Dynamic Type, readable text, non-color-only state, VoiceOver, SF Symbols, haptics, meaningful animation.

## Project Map

- `project.yml`: XcodeGen source of truth; regenerate `Trinket.xcodeproj`, do not edit it manually.
- `Trinket/BattleModels.swift`: battle rules and state.
- `Trinket/ContentView.swift`: SwiftUI shell, navigation, current battle UI.
- `TrinketTests/BattleStateTests.swift`: logic coverage.
- `TrinketUITests/CoreNavigationUITests.swift`: navigation/UI smoke coverage.

## Commands And Verification

- Commands: `./Scripts/generate.sh`, `./Scripts/build.sh`, `./Scripts/test.sh`, `./Scripts/run-simulator.sh`, `./Scripts/run-debug-battle.sh Mage Drake`.
- Run `./Scripts/test.sh` for logic changes and `./Scripts/build.sh` for UI/project/config. After `project.yml` or target membership changes, run `./Scripts/generate.sh` before build/test.
- For user-visible changes, run `./Scripts/run-simulator.sh` when feasible; capture screenshots only for useful visual evidence.
- Use the simulator for high-signal visual checks, not exhaustive UI proof. Prefer XCTest/XCUITest for routine navigation, sheet, log, and state checks.
- For battle timing, use the DEBUG deterministic Battle harness instead of sleeps or manual tapping.
- Keep generated build output and `.DerivedData/` out of Git.

## Tooling And Git

- Current harness: XcodeGen, `xcodebuild` scripts, XCTest, early XCUITest.
- Add SwiftLint, formatting, broader XCUITest, and snapshots only when ready.
- Make small commits around working states; prefer implementation plus verification over speculative refactors.
