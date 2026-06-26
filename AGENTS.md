# AGENTS.md

Guidance for Codex and other coding agents working on Trinket.

## Product Direction

Trinket is an iOS game learning project: a portrait-first fantasy idle auto-battler with heroes, pets, abilities, items, enemies, and homestead base-building.

## Agent Workflow

- Start code tasks with `git status --porcelain`. Treat existing changes as in-flight user work: understand them before editing, preserve user intent, and improve them when they intersect with the task.
- For non-trivial work, discover relevant local docs with `rg --files -g '*.md'` and focused `rg <topic>` searches. Read only what matches the task; prefer specific subsystem docs over broad assumptions.
- Optimize for product and engineering quality over short-term development cost. Prefer simplicity, robustness, scalability, maintainability, and clear ownership even when the implementation takes longer.
- For bug fixes, start by reproducing the issue with an end-to-end test or the closest practical automated/user-visible reproduction. A fix should be verifiable, not just plausible.
- Start from an end-to-end-verifiable user flow whenever possible, then use focused tests to cover implementation details.
- Treat lint failures, test failures, and flaky tests as real engineering problems. Keep the harness trustworthy and repair weak verification when it starts hiding risk.
- Challenge weak ideas, including user requests, when there is a better product or architecture path. Explain the tradeoff clearly and let merit, elegance, and long-term maintainability win.
- If the same approach fails three times, stop, reassess with relevant docs, build logs, tests, or Apple guidance, and ask for direction rather than continuing speculative fixes.
- When wrapping up, report what changed, what verification ran, and anything intentionally left untouched.

## Local Docs Routing

Before non-trivial work, use focused `rg` searches and read the most relevant docs.

- `Docs/CoreDesignConcepts.md`: read for gameplay, collection, battle, card, item, keyword, hero, pet, enemy, ability, homestead, progression, or reward design work.
- `Docs/AppleNativeGuidelines.md`: read for meaningful UI, accessibility, privacy, monetization, platform, App Store, or Apple-native behavior decisions.

## Durable Decisions

- Platform: iOS, iPhone-first, portrait-first.
- UI stack: prefer Apple-native Swift, SwiftUI, SpriteKit, UIKit, Foundation, CoreGraphics, AVFoundation, GameKit, StoreKit, etc.
- Apple guidance: follow `Docs/AppleNativeGuidelines.md` and refresh against official Apple docs before major UI, privacy, monetization, accessibility, or App Store decisions.
- Project workflow: CLI-first and agent-friendly through XcodeGen and scripts.
- Xcode project: `project.yml` is the source of truth; regenerate `Trinket.xcodeproj` instead of manually editing project files.
- Core navigation: native persistent bottom `TabView`.
- Top-level tabs: `Play`, `Heroes`, `Pets`, `Homestead`, `Options`; launch defaults to `Play`.
- First battle skeleton: `Play -> Battle -> Select Hero -> Select Pet -> Battle`.
- Combat default: idle auto-battle. Hero and Pet alternate abilities against a single enemy.
- Implemented Keywords: `Physical` direct damage and `Burn` enemy damage-over-time.
- Burn status proof point: each Burn application keeps its own damage amount and duration; battle ticks aggregate active stacks into one Burn damage event.
- Victory flow: defeated enemies show a full-screen-style outcome state with placeholder `Experience` and `Rewards` sections plus `Battle Again`; there is no `Change Party` action yet.
- DEBUG builds can launch directly into a paused deterministic Battle harness. This is an agent/development aid, not player-facing product UI.
- Core design concepts live in `Docs/CoreDesignConcepts.md`.

## Architecture And UX

- Keep early gameplay experiments simple and inspectable.
- Separate game rules/state from rendering when practical, so rules can be unit tested.
- Use SwiftUI for app shell, menus, settings, overlays, and simple prototypes.
- Use SpriteKit when gameplay needs a 2D scene loop, sprites, physics, particles, collision, or high-frequency animation; current combat feedback remains SwiftUI-only.
- Keep top-level game areas as tabs; use `NavigationStack` back buttons only for drill-in detail screens within a tab.
- Prefer small types with clear ownership over broad manager objects.
- Add abstractions only after repeated behavior appears.
- Trinket should feel smooth, native, polished, accessible, and carefully crafted.
- Keep primary controls near the bottom for thumb reachability, respect safe areas, and support Dynamic Type where appropriate.
- Use native controls for non-game UI: `Button`, `NavigationStack`, sheets, menus, toggles, sliders, haptics, and system materials.
- Prefer SF Symbols for system actions and navigation until custom art has a clear gameplay or brand purpose.
- Accessibility is part of the baseline: readable text, accessible labels, non-color-only state, and VoiceOver-friendly structure.
- Use haptics and animation intentionally for meaningful feedback.

## Harness Commands

Run these from the repository root.

```sh
./Scripts/generate.sh
./Scripts/build.sh
./Scripts/test.sh
./Scripts/run-simulator.sh
./Scripts/run-debug-battle.sh Mage Drake
```

## Verification Expectations

- Run `./Scripts/test.sh` for logic changes.
- Run `./Scripts/build.sh` for UI/project/config changes.
- Run `./Scripts/run-simulator.sh` for user-visible changes when feasible.
- Capture a simulator screenshot for meaningful visual changes.
- For meaningful UI changes, compare the result against `Docs/AppleNativeGuidelines.md`.
- Keep generated build output and `.DerivedData/` out of Git.

## Simulator Efficiency

- Use the simulator for high-signal visual checks, not exhaustive proof of every UI state.
- Prefer `./Scripts/test.sh` and XCUITest for routine navigation, sheet, log, and state verification.
- For battle timing, prefer the DEBUG-only Battle harness over sleeps or manual tapping.
- Harness controls have accessibility identifiers for deterministic ticks, reset, pause/resume, and victory.
- `xcrun simctl io booted screenshot <path>` is reliable for screenshots.
- Keep screenshots in `Screenshots/` only when they document useful visual evidence.

## Tooling Direction

Current minimum useful harness: XcodeGen, `xcodebuild` scripts, and XCTest.

Add SwiftLint, a formatter, XCUITest smoke tests, and snapshot testing only when the app is ready for them.

## Git Hygiene

- Treat generated `Trinket.xcodeproj` as a generated artifact from `project.yml`.
- Do not commit `.DerivedData/`.
- Make small commits around working states.
- Prefer implementation plus verification over large speculative refactors.
