# Testing

Unit and UI test conventions for Trinket. Agent workflow overview and definition of done: **`AGENTS.md`**. Battle ownership matrix: `Packages/BattleEngine/Tests/README.md`. UI launch args / speed: `TrinketUITests/README.md`.

## Framework split

**Swift Testing only** in `TrinketTests/` and package test targets (`import Testing`). **XCTest** only in `TrinketUITests/`. Enforced by `./Scripts/check-swift-testing-migration.sh`.

Mirror production folders under `TrinketTests/`. SwiftUI `Features/*` views → UI smoke/deploy, not unit tests.

## Ownership

| Concern | Owner |
|---------|-------|
| Battle rules / handlers / golden paths | `Packages/BattleEngine/Tests/` (see that package’s README) |
| Catalogs / content invariants | `TrinketContentTests` |
| Stores / persistence write-through | `TrinketPersistenceTests` |
| App shell (`AppState`, `BattleSession`, …) | `TrinketTests/` only |

## Fixtures

Prefer `TrinketTestSupport` (`CombatantFixtures`, `SaveTestSupport`, battle parties). App suites: `AppTestContext` / `AppTestSupport`. Persistence: `PersistenceTestContext`. Battle RNG: always `BattleStateTestFactory.makeBattle(...)` with `rngSeed: 0`; dispatch via `EffectHandlers.all`.

## Unit conventions

- **Naming:** `@Test func behaviorWhenCondition()` — no `test` prefix required.
- **Assertions:** `#expect`; `try #require` / `#require` to unwrap; `Issue.record` for unconditional failures.
- **Parameterization:** `@Test(arguments:)` for catalog loops and symmetric keyword variants.
- **Lifecycle:** Prefer `@Suite` on package tests. In `TrinketTests`, `struct …Tests` + `@Test` is fine. Use `@MainActor` when UI/layout/store isolation requires it. Use `final class` + `init() throws` only for teardown ownership (`AppTestContext` / `PersistenceTestContext`).
- **Stores:** mutate → reload from disk → `#expect`.
- **Async/debounce:** inject short intervals in production inits; poll in tests — never `Task.sleep` for multi-second production delays.
- **Events:** pin outcome counters; assert event *semantics*, not full log fingerprints.
- **Do not unit-test:** log prose (except a few representative formatter cases), `TrinketDesign` styling, AVFoundation playback, real CloudKit I/O.

## Definition of done (new features)

1. Rules/models → focused unit test in the owning package.
2. New `Player*Store` API → write-through persistence test in `TrinketPersistenceTests`.
3. New catalog content → invariant test in the matching `*CatalogTests` (`TrinketContentTests`).
4. New `EffectKind` → registry parity + `EffectHandlersApplyTests`; thin integration only for multi-effect combos.
5. New app orchestration on `AppState` / `BattleSession` → focused `TrinketTests` test.
6. New user flow → `AccessibilityID` (or existing id) + one smoke UI test.
7. Run `./Scripts/test.sh unit` (full, unfiltered) before commit when package code changed (toolchain permitting).

## UI tests (summary)

Local/agent default: `./Scripts/test.sh smoke` runs the Homestead canary (`QuickSmoke.xctestplan`). Full smoke (`smoke-full`) is CI/PR only. Exhaustive journeys → `test.sh ui` / `test-deploy.sh` only.

Default smoke args: `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`. Prefer `-launch-screen` / `-selectedTab` deep links; avoid Play-map scroll loops. Assert with `assertExists` on ids from `AccessibilityID`. UI tests tap tab **labels** (`"Homestead"`, `"Collection"`), not `AppTab` raw values.

Full layout, launch-arg catalog, speed rules, and mid-battle guidance: **`TrinketUITests/README.md`**.
