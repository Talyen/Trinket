# Testing

Unit and UI test conventions for Trinket. Agent workflow / command router: **`AGENTS.md`**. This file owns the definition of done and test conventions. Battle ownership matrix: `Packages/BattleEngine/Tests/README.md`. UI launch args / speed: `TrinketUITests/README.md`.

## Framework split

**Swift Testing only** in `TrinketTests/` and package test targets (`import Testing`). **XCTest** only in `TrinketUITests/`. Enforced by `./Scripts/check-swift-testing-migration.sh`.

Keep semantic tests beside their owning package. `TrinketTests` is reserved for
integration behavior that truly belongs to the final app target. SwiftUI shipping
journeys use UI smoke/deploy only when the keep/drop rubric below applies.

## Ownership

| Concern | Owner |
|---------|-------|
| Battle rules / handlers / golden paths | `Packages/BattleEngine/Tests/` (see that package’s README) |
| Shared presentation models / caches / frame analysis | `Packages/TrinketFeatureSupport/Tests/` |
| Battle session / feedback / spectacle / layout | `Packages/TrinketBattleFeature/Tests/` |
| AppState / Play and encounter sessions / options / audio routing | `Packages/TrinketAppState/Tests/` |
| Catalogs / content invariants | `TrinketContentTests` |
| Stores / persistence write-through | `TrinketPersistenceTests` |
| Final app-target integration only | `TrinketTests/` |

## Fixtures

Prefer `TrinketTestSupport` (`CombatantFixtures`, battle parties). Save harnesses live
beside Persistence and AppState tests—not in `TrinketTestSupport`—so TestSupport stays
Persistence-free. App suites use `AppTestContext` / `AppTestSupport`; Persistence uses
`PersistenceTestContext`. Battle RNG: always
`BattleStateTestFactory.makeBattle(...)` with `rngSeed: 0`; dispatch via
`EffectHandlers.all`.

## Unit conventions

- **Naming:** `@Test func behaviorWhenCondition()` — no `test` prefix required.
- **Assertions:** `#expect`; `try #require` / `#require` to unwrap; `Issue.record` for unconditional failures.
  - Keep `#require` arguments simple `Optional`s (or values that expand cleanly). Compute rich expressions first — e.g. `let node = collection.first(where: \.flag); try #require(node)` — so Swift Testing macros do not emit “missing try” compile errors.
  - Prefer key-path `first(where:)` / `contains(where:)` forms when SwiftLint `prefer_key_path` applies; still split before `#require`.
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

## Coverage decision (new and changed behavior)

Verification does not imply authoring new tests. Add or expand coverage only when all are true:

1. The change introduces or repairs a distinct, consequential behavior or invariant.
2. No existing test already owns it.
3. The proposed assertion would fail before the fix, except for genuinely new behavior.
4. The cheapest suitable tier can express it without duplicating a stronger owner.
5. An existing semantic matrix, journey, method, or file cannot absorb it more cheaply.

Prefer extending an existing owner over adding a declaration, and a declaration over a new file or class. Remove or merge coverage made redundant by the change. Do not test plumbing, stored-property round trips, display copy, layout constants, framework behavior, or trivial delegation.

**Likely owners when the gate passes:** rules/models → owning package; persistence semantics → existing store/sanitizer journey; catalog content → invariant matrix, not exact-count snapshots; novel `EffectKind` behavior → existing registry/handler matrix; consequential app transitions that packages cannot own → `TrinketTests`.

New user flows still need a stable `AccessibilityID` selector (or an existing appropriate one), but add or extend a UI test only when the keep/drop rubric below applies. Prefer an existing smoke/exhaustive method over a new class; assert visible outcomes, not custom accessibility prose.

### Presentation / accessibility-ID changes (before push)

Renaming or rewiring `AccessibilityID`, a view `accessibilityIdentifier`, or Homestead/Play presentation contracts is not a style-only change:

1. Run path-scoped `./Scripts/verify-changed.sh --isolate --paths …` and complete every routed unit/smoke step (do not stop after style).
2. `Packages/TrinketFeatureSupport/.../AccessibilityID.swift` routes through the
   shared-support package check; UI callers route to their lean smoke owner.
3. Homestead presentation models route through `TrinketFeatureSupportTests`.
4. `./Scripts/test.sh style` (or the verify-changed style step) must pass locally — the pre-push hook enforces SwiftFormat/SwiftLint, but agents should not discover format failures only at push time.

Verify with the AGENTS Task→Command Router (toolchain permitting), using
   **`--isolate` / `TRINKET_ISOLATE=1` for agent runs**:

- **Agent handoff** → `./Scripts/verify-changed.sh --isolate --paths <files>`
- **Package-only iteration** → `TRINKET_ISOLATE=1 ./Scripts/test-package.sh <Package>`
- **App orchestration iteration** → `TRINKET_ISOLATE=1 ./Scripts/test-package.sh TrinketAppState`
- **Small UI feature** → the path-scoped route with the closest existing `<SmokeClass>/<testMethod>` when the rubric calls for UI ownership. If none exists, do not create one merely because a view changed.
- **Cross-cutting UI** → affected focused smoke owners only during iteration. Full unit, bare smoke, `smoke-full`, and exhaustive UI remain pre-push/CI work.

Compile-only and other path-scoped tiers: `Docs/AgentContext/ci-and-project-generation.md`.

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

Battle frame pacing is not part of smoke. Run the exclusive single-report matrix with `./Scripts/performance.sh`. Focused harness iteration: `TRINKET_ISOLATE=1 ./Scripts/test.sh performance BattlePerformanceUITests/<method>`. The dedicated plan records refresh-normalized display-link diagnostics; use Instruments Animation Hitches and Time Profiler for render-pipeline investigation. Launch arg `-enable-frame-metrics` is measurement-only and must not simplify Battle rendering or audio. Investigation loop and baseline policy: `Docs/Platform/PerformanceInvestigationPlaybook.md`.

Default smoke args: `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`. Prefer `-launch-screen` / `-selectedTab` deep links; avoid Play-map scroll loops. Assert with `assertExists` on ids from `AccessibilityID`, then verify visible text or interaction outcomes where behavior matters. UI tests tap tab **labels** (`"Homestead"`, `"Collection"`), not `AppTab` raw values. Accessibility audits and accessibility-setting permutations are not part of the test matrix. The Frame Metrics node is an explicit machine bridge used only by the performance plan (not VoiceOver product semantics).

Glass primary CTAs (`trinketPrimaryActionButton`) must receive their `AccessibilityID` via the
modifier’s `accessibilityIdentifier:` parameter. Identifiers applied before `.glassProminent`
are dropped from the XCUITest tree; label fallbacks are a last resort only.

Full layout, launch-arg catalog, speed rules, and mid-battle guidance: **`TrinketUITests/README.md`**.
