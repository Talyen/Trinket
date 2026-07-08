# AGENTS.md

Guidance for agents on Trinket: portrait-first iOS fantasy idle auto-battler.

## Platform Baseline (read first)

Trinket is a **2026-native iOS app**. Treat anything targeting iOS 25 or earlier as wrong unless the user explicitly asks for it.

| Requirement | Value | Source of truth |
|-------------|-------|-----------------|
| Minimum OS | **iOS 26.0** | `project.yml` `deploymentTarget` |
| Language | **Swift 6.0** | `project.yml` `SWIFT_VERSION` |
| Toolchain | **Xcode 26+** | `README.md` |
| Concurrency | **Strict** (`SWIFT_STRICT_CONCURRENCY: complete`) | `project.yml` |
| UI framework | **SwiftUI** (no UIKit bridges unless unavoidable) | app target |
| Unit tests | **Swift Testing** (`import Testing`) | `TrinketTests/`, package tests |
| UI tests | **XCTest** (`TrinketUITests/`) | smoke/deploy plans |

**Do not:**

- Add `#available` / `@available` checks for iOS versions below 26 — we do not ship to older OSes.
- Introduce `NavigationView`, `ObservableObject`, `@StateObject`, or `@Published` in new code.
- Hand-roll materials, glass, or button styles in feature views — use `TrinketDesignSystem` (see `./Scripts/check-ui-style.sh`).
- Assume UIKit patterns (manual layout, `UIViewRepresentable`) when SwiftUI has a first-party API.

**Do:**

- Use `@Observable` + `@Environment(Type.self)` + `@Bindable` for app state (see `Trinket/State/AppState.swift`, `Trinket/App/ContentView.swift`).
- Use `NavigationStack`, modern `Tab` (including `role: .search`), sheets, `ToolbarItem`, semantic colors.
- Use SwiftData (`@Model`) for persistence — see `TrinketPersistence`.
- Route chrome through `TrinketDesign` / `.trinketSurface` / `.trinketMaterial` / `.trinketGlassChip` in `TrinketDesignSystem`.
- When unsure, **grep the repo** for an existing pattern before inventing one.

“Fallbacks” in design docs mean **accessibility** (Reduce Transparency / Reduce Motion), not older iOS support.

## When To Read What

- Workflow/scripts/style: `AGENTS.md` · architecture/repo map: `Docs/Architecture.md` · gameplay vocabulary: `Docs/Design/CoreDesignConcepts.md` · future ideas: `Docs/Roadmap.md` · Apple HIG: `Docs/Design/AppleNativeGuidelines.md` · style guide: `Docs/Design/StyleGuide/AppVisualFoundation.md` · art: `ArtManifest/README.md` · content: `ContentManifest/README.md` · music: `MusicManifest/README.md` · releases: `Scripts/README.md` · setup: `README.md`
- Roadmap items in `Docs/Roadmap.md` are speculative. Do not implement them unless the user explicitly asks to explore or build a cited `R-###` entry.
- `Docs/Audits/*Audit.md` files are point-in-time audit snapshots — not workflow docs. Do not treat them as active requirements unless the user cites one.

## Product & Architecture

- iOS iPhone-first, portrait-only (`project.yml`). Swift 6.0 / SwiftUI; iOS 26.0. Public Apple APIs for StoreKit, GameKit, privacy, cloud, etc.; update docs with App Store/privacy implications.
- SwiftUI for shell/menus/overlays and battle presentation. Rules/state separate from rendering; small owned types; abstract after repetition. Local Swift packages: see `Docs/Architecture.md`.
- **Repo map:** read `Docs/Architecture.md` first. App target under `Trinket/`; shared packages under `Packages/`; manifests at repo root (`ContentManifest/`, `ArtManifest/`, …); tests in `TrinketTests/` and `TrinketUITests/`.
- **Product tabs vs code** (see `Docs/Architecture.md` for the full table):

  | UI label | `AppTab` | Notes |
  |----------|----------|-------|
  | Play | `.play` | Chapter journey |
  | Collection | `.collection` | In-tab switch: Heroes / Pets / Inventory |
  | Homestead | `.homestead` | |
  | Search | `.search` | Inventory search utility (`Tab` role `.search`); not a primary product tab |
  | Options | `.options` | |

  Product vocabulary in `Docs/Design/CoreDesignConcepts.md` uses Heroes and Inventory as collection surfaces inside the Collection tab. UI tests tap tab labels like `"Homestead"` and `"Collection"`, not enum raw values.
- **Generated output** — edit manifests, then `./Scripts/generate.sh` (`ContentManifest/README.md`, `Docs/Architecture.md`):
  - Catalogs: `Packages/TrinketContent/Sources/TrinketContent/Generated/*`
  - Art: `Trinket/Assets.xcassets` (via `prepare-art-assets.sh`, requires `--assets`)
  - Music: `Trinket/Resources/Music` (via `prepare-music-assets.sh`, requires `--assets`)
  - SFX catalog: generated Swift in TrinketContent (via `prepare-sfx-assets.sh`, requires `--assets`)
  - Shared domain types: `Packages/TrinketCore/` (`CombatantProgression`, effects, enums). `Raw Assets/` is source-only.
  - Don't hand-edit generated output, `.DerivedData/`, build products, or `.swiftlint.yml` severity (without reason here).

## Battle Module

Combat rules live in `Packages/BattleEngine/` (`BattleState`, effect handlers, simulator, `Combatant`, roster/enemy catalogs). App shell: `Trinket/State/BattleSession.swift`, `Trinket/BattleShell/ActiveBattleConfiguration.swift`, `Trinket/BattleShell/BattleVictorySummary.swift`.

Key patterns:
- Effects are value-type structs conforming to `BattleEffectHandler`; lookup by `EffectKind` dictionary in `BattleState`.
- Test determinism: use `BattleStateTestFactory.makeBattle(...)` in `BattleEngineTests` (seed 0) instead of raw `BattleState(...)`.

## Apple-Native Product Rules

- System SwiftUI, SF Symbols, Dynamic Type, accessibility, semantic colors/materials. Major UI: `Docs/Design/AppleNativeGuidelines.md`. Swift API Design Guidelines; testably separate models, rules, rendering, persistence, platform services.
- `TabView` top-level only; `NavigationStack`, sheets, alerts, menus, `ToolbarItem` for detail. Portrait, thumb-reachable; VoiceOver, Reduce Motion, contrast, Dynamic Type.
- Chrome via `TrinketDesign`; avoid ad-hoc `.buttonStyle`, materials, capsules, and simulated glass. Native glass via `.glassEffect()` in `TrinketDesignSystem`; solid-surface fallback when Reduce Transparency is on. `Toggle` modes, `Button` actions; `controlSize`, `buttonBorderShape`, `Label`, semantic styles. `TrinketDesignSystem` depends on `TrinketCore` only (not `BattleEngine` or `TrinketContent`). Homestead node tint presentation lives in `Trinket/Models/Homestead.swift`.
- **Style Guardrail Triggers**: `./Scripts/check-ui-style.sh` flags:
  - Raw materials: `.background` or `.fill` with `.regularMaterial`, `.thinMaterial`, or `.ultraThinMaterial`.
  - Raw button/toggle styles: `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)`, `.buttonStyle(.bordered)`, `.buttonStyle(.borderedProminent)`, and `.toggleStyle(.button)`.
  - Fixed interactive dimensions inside buttons: `.frame(width: ...)` or `.frame(height: ...)` when paired with text/fonts.
- **Bypass**: Use `// UIStyleCheck: allow - <reason>` (on the same or preceding line) for deliberate one-offs. Otherwise, route all reusable components and styling rules through `Packages/TrinketDesignSystem/`.

## Git Workflow

- Work on `main` unless the user explicitly requests a feature branch.
- Commit locally when work is complete or before testing.
- Do **not** `git push` unless the user explicitly asks.
- Do **not** create or update pull requests unless the user explicitly asks.
- Cloud-agent environments may use feature branches and PRs when configured; follow the active session instructions when they differ from the rules above.

## Commit Messages

Use this structure so release automation can generate changelogs and App Store notes:

```
<type>(<scope>): <imperative subject ≤72 chars>

- <notable change>
- <another change>

User-Facing: yes | no
Breaking: <description if only applicable>
```

- **Types:** `feat`, `fix`, `perf`, `refactor`, `content`, `style`, `test`, `ci`, `chore`, `docs`
- Imperative subjects without a type prefix are acceptable (`Add session state restoration…`).
- Set **`User-Facing: yes`** when players would notice; **`User-Facing: no`** for CI/style/refactor/tooling.
- Do **not** edit `CHANGELOG.md` per commit — `./Scripts/release.sh` generates it at release time.
- See `Scripts/README.md` for the full release workflow.
- Optional local hook: `git config core.hooksPath .githooks` (advisory warnings via `./Scripts/validate-commit-msg.sh`).

## Commands & Verification

Scripts live under `./Scripts/`. `test.sh` records per-run timings to `.DerivedData/TestResults/timing-log.jsonl`; `./Scripts/test-timing.sh` reports recent runs and slow-test hotspots without re-running tests. Tooling: XcodeGen, `xcodebuild`, XCTest, SwiftFormat, SwiftLint. `test.sh` runs `generate.sh` then builds then tests. Pass `--no-build` to rerun an already-built test binary (skips the fresh build, but refuses stale sources). After `project.yml` changes, run `generate.sh` before build/test.

**Script groups:**

| Group | Scripts |
|-------|---------|
| Codegen | `generate.sh`, `validate-manifests.sh`, `assert-generated-output.sh`, `prepare-art-assets.sh`, `prepare-music-assets.sh`, `prepare-sfx-assets.sh`, `generate-content-catalogs.sh`, `generate-ability-shorthand.sh` |
| Quality | `format.sh`, `lint.sh`, `check-ui-style.sh` (`test.sh style`), `check-module-boundaries.sh` |
| Build/test | `build.sh`, `build-for-testing.sh`, `test.sh`, `test-package.sh`, `test-iterate.sh`, `test-deploy.sh`, `ci-locally.sh`, `test-timing.sh`, `run-simulator.sh`, `capture-screenshot.sh`, `balance-sweep.sh` |
| Release | `release.sh`, `release-notes.sh`, `release-notes-user.sh`, `validate-commit-msg.sh` |

**Gate scripts:**

| Script | Runs |
|--------|------|
| `ci-locally.sh` | generate → assert-generated-output → module boundaries → style → unit → smoke |
| `test-deploy.sh` | generate → assert-generated-output → module boundaries → style → validate release notes → unit → full UI |
| GitHub CI (`pr.yml`, PRs) | gate → unit + smoke (parallel) |
| GitHub CI (`ci.yml`, main) | gate → unit + full UI (parallel) |

| Change | Check |
|--------|-------|
| One-screen layout | `build.sh` or `run-simulator.sh` |
| Styling | `check-ui-style.sh` + smoke |
| Rules/models | `test.sh unit <Tests>`; full unit mode also runs all five package test schemes |
| Multi-step UI | `test-iterate.sh <SmokeClass> [ExhaustiveClass]` |
| Pre-push | `ci-locally.sh` |
| Pre-merge | `test-deploy.sh` |
| Release | `release.sh` (see `Scripts/README.md`) |

**Test tiers** (fast → thorough):

| Tier | Command | What runs | When |
|------|---------|-----------|------|
| Unit | `test.sh unit` | `TrinketTests` + all five package schemes (sequential) | Every logic change |
| Unit (filtered) | `test.sh unit <Class>` | App tests only (`TrinketTests/<Class>`) | Focused app logic |
| Package unit | `test-package.sh <Package>` | One package scheme from inside `Packages/<Package>` | Focused package logic |
| UI smoke | `test.sh smoke` | `Smoke.xctestplan` — 9 `Smoke*` UI classes only (~2 min) | Tab/screen edits, pre-push |
| Targeted UI | `test.sh ui <Class>` | One UI class | Focused UI iteration |
| Full UI | `test.sh ui` | All `TrinketUITests` including exhaustive flows | Pre-merge |
| Integration | `test.sh all` | `Integration.xctestplan` — unit + all UI in one run | Nightly / manual |

`Smoke.xctestplan` is **UI smoke only** (not unit tests). `Unit.xctestplan` and `FullUI.xctestplan` back `test.sh unit` and `test.sh ui`. `test-deploy.sh` runs style → unit → full UI once (smoke is a subset, not rerun).

Iteration: **unit** → **smoke class** → **exhaustive class** before merge. Keep diffs focused and run `ci-locally.sh` before push.
- **Fast iteration tips**:
  - Test a single local package scheme (skip full app build): `./Scripts/test-package.sh BattleEngine`
  - Filter unit tests (runs app target tests only): `./Scripts/test.sh unit BattleStateTests`
  - Run a single UI test smoke class: `./Scripts/test.sh ui SmokeCollectionTests`
  - Re-run built binaries without rebuilding (massive speedup): Add `--no-build` (e.g., `./Scripts/test.sh ui SmokeCollectionTests --no-build` or `./Scripts/test.sh unit BattleStateTests --no-build`).
  - Interactive iteration flow: `./Scripts/test-iterate.sh SmokeCollectionTests TabNavigationUITests`
- **Test ownership**: Battle rule tests live in `BattleEngineTests`; persistence tests in `TrinketPersistenceTests`. `BattleSimulator` lives in `Packages/BattleEngine/`.
- **Speed Tip**: Avoid `ci-locally.sh` or `test-deploy.sh` during active development. Compile with `build.sh` or run simulator previews.

## Unit Tests

Framework: **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect` / `#require`) for all unit and integration tests in `TrinketTests/` and package test targets. **XCTest** remains only for `TrinketUITests/` (`XCUIApplication`, performance metrics). XCTest and Swift Testing coexist in the same target during migration; unit targets must not import XCTest when migration is complete (`./Scripts/check-swift-testing-migration.sh`).

Mirror production folders under `TrinketTests/` (`Battle/`, `Persistence/`, `State/`, etc.). SwiftUI `Features/*` views are covered by UI smoke/deploy tests, not unit tests.

### Shared helpers

| Helper | Location | Use for |
|--------|----------|---------|
| `AppTestContext` | `TrinketTests/Support/` | Per-suite temp save dir + `UserDefaults` + `makeAppState` |
| `PersistenceTestContext` | `TrinketPersistenceTests/Support/` | Temp directory lifecycle for store roundtrip tests |
| `SaveTestSupport` | `TrinketTests/Support/` · `TrinketPersistenceTests/Support/` | Temp save directories and `PlayerSaveStore` factories |
| `AppTestSupport` | `TrinketTests/Support/` | Stateless `makeAppState` when caller owns `directoryURL` |
| `CombatantFixtures` | `TrinketTests/Support/` (app) · `Packages/BattleEngine/Tests/.../Support/` (battle) | Minimal combatants and abilities |
| `BattleStateTestFactory` | `Packages/BattleEngine/Tests/BattleEngineTests/` | **Always** use for RNG-sensitive battle tests (`rngSeed: 0`) |
| `BattleTestFixtures` | `Packages/BattleEngine/Tests/BattleEngineTests/Support/` | Integration tick helpers, `standardParty`, effect predicates |

### Conventions

- **Naming:** `@Test func behaviorWhenCondition()` — e.g. `localMutationSchedulesDebouncedUpload`; no `test` prefix required.
- **Assertions:** `#expect` for behavioral checks; `try #require` / `#require` to unwrap and halt; `Issue.record` for unconditional failures.
- **Parameterization:** `@Test(arguments:)` for catalog loops and symmetric keyword variants (per-item failure isolation).
- **Lifecycle:** prefer `@Suite struct` for stateless tests; `@Suite @MainActor final class` with `init() throws` + `AppTestContext` / `PersistenceTestContext` when teardown is needed.
- **Main actor:** Swift Testing does not run sync tests on `@MainActor` by default — annotate suite or test when UI/layout/store isolation requires it.
- **Battle rules:** `BattleStateTestFactory.makeBattle(...)` instead of raw `BattleState(...)`.
- **BattleEngine ownership:** see `Packages/BattleEngine/Tests/README.md` — each mechanic has one primary test owner; integration files stay thin (3–6 tests) and only exercise full tick wiring.
- **Handler tests:** dispatch through `EffectHandlers.all`; use BattleEngine `CombatantFixtures` for setup.
- **Store tests:** `@Suite @MainActor final class` with `PersistenceTestContext`, mutate → reload from disk → `#expect`.
- **Async/debounce:** inject short intervals in production init params; poll in tests — never `Task.sleep` for multi-second production delays.
- **Golden paths:** pin outcome counters (ticks, health, victory/defeat); assert event *semantics* (status kinds, milestones) rather than full log fingerprints.
- **Ability descriptions:** `AbilityDescriptionFormatterTests` guards catalog prose; prefer focused examples over duplicating full catalog loops elsewhere.
- **Homestead rewards:** test `PlayerHomesteadState.adjustedMaterialRewards` directly, then stage-completion integration for end-to-end grants.
- **Battle UI flow:** use `BattleSession.outcome` and `BattleVictorySummary.make` — keep outcome logic out of SwiftUI views.
- **Launch screens:** collection deep links live on `AppState.initialCollectionCombatantDetail` / `initialCollectionItemID`, not `AppEnvironment.shared` in views.
- **Content invariants:** loop `GameContent` for catalog tests (unique IDs, art refs, stage→enemy links).
- **Do not unit-test:** log prose formatting details (except a few representative formatter cases), `TrinketDesign` styling, AVFoundation playback, real CloudKit I/O. Prefer semantic battle event assertions over full log fingerprints (`Packages/BattleEngine/Tests/README.md`).

### Definition of done (new features)

1. Rules/models → at least one focused unit test in the owning package.
2. New `Player*Store` API → write-through persistence test in `TrinketPersistenceTests`.
3. New catalog content → invariant test in the matching `*CatalogTests` class (`TrinketContentTests`).
4. New `EffectKind` → registry parity test + `EffectHandlersApplyTests`; optional thin integration only for multi-effect combos.
5. New app orchestration on `AppState` / `BattleSession` → focused `TrinketTests` test.
6. New user flow → `accessibilityIdentifier` + one smoke UI test.
7. Run `./Scripts/test.sh unit` (full, unfiltered) before commit when package code changed.

**Test ownership:** Battle rules → `Packages/BattleEngine/Tests/README.md`. Catalog invariants → `Packages/TrinketContent/Tests/` (`ArtCatalogIntegrationTests`, `GameContentCatalogInvariantTests`). App shell orchestration only in `TrinketTests/`.

## UI Tests

**Smoke** (`TrinketUITests/Smoke/`): lean per-screen checks via `Smoke.xctestplan`. **Exhaustive** (`Collection/`, `Battle/`, `Search/`): multi-step journeys only in `test.sh ui` / `test-deploy.sh`. **Support** (`TrinketUITests/Support/Screens/`): page-object helpers (`PlayScreen`, `TabBar`, …). One assertion theme per smoke method; split at ~20 lines.

**Launch args:** `TestLaunchArg` in `TrinketUITests/Support/TrinketUITestCase.swift`; parsed by `AppEnvironment` (`LaunchScreen` enum in `AppTypes.swift`). Helpers: `allForScreen`, `allForTab`, `allForBattle`, `completedStages`, `mapScrollTarget`.

Default smoke args (`TestLaunchArg.testLaunchArgs`): `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`. Additional args:

- `-launch-screen` (`hero:`, `pet:`, `item:`, `options`, `battle` starts stage 1-1)
- `-selectedTab` (`play`, `collection`, `homestead`, `search`, `options`; `heroes`/`pets`/`inventory` → `.collection`)
- `-completed-stages` (comma IDs)
- `-map-scroll-target` (Play map scroll row id)
- `-battle-tick-interval` (override fast ticks; avoid with mid-battle interaction tests)
- `-disable-audio`, `-appearance` (see `AppEnvironment.parse`)

Smoke classes `Smoke*` (files match class names). `.accessibilityIdentifier` like `"Stage 1-1 Node"`, `"Battle Button"`; use `assertExists`. Keep default launch args unless testing persistence.

**UI test speed** (check hotspots with `./Scripts/test-timing.sh report --top 30` and `./Scripts/test-timing.sh report --by-class`):
- Prefer `-launch-screen` / `-selectedTab` deep links over tab + grid navigation.
- Avoid `assertExistsAfterScroll` for far-off Play map nodes; use `-completed-stages` or `-map-scroll-target` instead.
- Use inventory/search field filtering (`replaceText`) instead of long grid scroll loops.
- Mid-battle exhaustive tests should enter via Play map, not `-launch-screen battle` with very fast tick intervals.
- UI tests run serially on a single simulator by default.
