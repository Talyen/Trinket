# Testing

Unit and UI test conventions for Trinket. Agent workflow / command router: **`AGENTS.md`**. This file owns the definition of done and test conventions. Battle ownership matrix: `Packages/BattleEngine/Tests/README.md`. UI launch args / speed: `TrinketUITests/README.md`.

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
  - If the argument type is a `private` nested enum/struct, the `@Test` function must also be
    `private` (Swift rejects a more-visible method that exposes a private parameter type).
  - Argument types used in `@Test(arguments:)` tuples must be `Sendable` (and usually
    `Hashable` / `Equatable`). Nested types like `Keyword.Category` need the same
    conformances even when the parent type already has them.
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
6. New user flow → stable `AccessibilityID` test selector (or existing id). Add or extend a UI test **only** when the keep/drop rubric below applies; prefer extending an existing smoke/exhaustive method over adding a new class. Keep assertions on visible UI state and interaction outcomes; do not test custom accessibility labels or values.
7. Verify with the AGENTS Task→Command Router (toolchain permitting), using
   **`--isolate` / `TRINKET_ISOLATE=1` for agent runs**:
   - **Agent handoff** → `./Scripts/verify-changed.sh --isolate --paths <files>`
   - **Package-only** change → `TRINKET_ISOLATE=1 ./Scripts/test-package.sh <Package>`
   - **App orchestration** → `TRINKET_ISOLATE=1 ./Scripts/test.sh unit <Class>` (or full unit when cross-cutting)
   - **Small UI feature** → `./Scripts/verify-changed.sh --isolate --paths <file...>` (style + closest focused smoke; package tests when packages are touched); use `<SmokeClass>/<testMethod>` when one method directly owns the behavior. If no class covers it, add or update one focused smoke test first.
   - **Cross-cutting UI** → run the affected focused smoke classes during iteration (still via path-scoped verify so style is included). Full unit, bare smoke, `smoke-full`, and exhaustive UI suites remain pre-push / CI work via `ci-locally.sh` / PR workflows.

## UI keep / drop rubric

Keep a UI test only if it asserts a **shipping product outcome** that unit/package tests cannot own:

1. **Shell / entry** — a major surface becomes usable (Play chooser, Homestead wallet, Shop controls, Battle chrome).
2. **State-changing journey** — a user action mutates durable or navigable state (purchase unlocks next stage, equip persists, retreat returns to Play, chapter advance, recruit continue).
3. **Safety invariant** — a wrong interaction must not happen (locked slot inert; hand drag must not open detail). **One owner only** across smoke + exhaustive.

Do **not** UI-test (delete or never add): marketing/copy strings, nav titles, unexpected-text catalogs, layout/chrome mirrors (overscroll, swipe scroll ownership, grid layout), mid-battle detail marathons that race live ticks, or second copies of the same interaction across smoke and FullUI. Push loadout, party-selection, and unlock rules down to `TrinketTests` / package tests when possible; UI proves the sheet/control path once.

**Brittleness:** assert `AccessibilityID` plus one visible outcome (exists / dismissed / tab returned). Never pin display names, rarity labels, or scroll geometry unless that string is the product contract.

Smoke = short shell canaries (`smoke-full` ≈ five lean methods). Exhaustive FullUI = state-changing journeys only. Mid-battle interaction safety (hand drag) lives in FullUI; agents still route BattleHandView changes to `SmokeBattleTests` load canary.

## UI tests (summary)

Bare `./Scripts/test.sh smoke` runs the Homestead canary (`QuickSmoke.xctestplan`) and is a pre-push gate, not a generic feature check. Agents use `TRINKET_ISOLATE=1 ./Scripts/test.sh smoke <SmokeClass>` (or `verify-changed --isolate`) for the affected feature. Full smoke (`smoke-full`) is CI/PR only. Exhaustive journeys → `test.sh ui` / `test-deploy.sh` only.

Battle frame pacing is not part of smoke. Run the exclusive single-report matrix with `./Scripts/performance.sh`. Focused harness iteration: `TRINKET_ISOLATE=1 ./Scripts/test.sh performance BattlePerformanceUITests/<method>`. The dedicated plan records native `XCTHitchMetric` data and refresh-normalized raw deadline reports. Launch arg `-enable-frame-metrics` is measurement-only and must not simplify Battle rendering or audio. Investigation loop and baseline policy: `Docs/Platform/PerformanceInvestigationPlaybook.md`.

Default smoke args: `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`. Prefer `-launch-screen` / `-selectedTab` deep links; avoid Play-map scroll loops. Assert with `assertExists` on ids from `AccessibilityID`, then verify visible text or interaction outcomes where behavior matters. UI tests tap tab **labels** (`"Homestead"`, `"Collection"`), not `AppTab` raw values. Accessibility audits and accessibility-setting permutations are not part of the test matrix. The Frame Metrics node is an explicit machine bridge used only by the performance plan (not VoiceOver product semantics).

Glass primary CTAs (`trinketPrimaryActionButton`) must receive their `AccessibilityID` via the
modifier’s `accessibilityIdentifier:` parameter. Identifiers applied before `.glassProminent`
are dropped from the XCUITest tree; label fallbacks are a last resort only.

Full layout, launch-arg catalog, speed rules, and mid-battle guidance: **`TrinketUITests/README.md`**.
