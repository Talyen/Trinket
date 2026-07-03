# AGENTS.md

Guidance for agents on Trinket: portrait-first iOS fantasy idle auto-battler.

## When To Read What

- Workflow/scripts/style: `AGENTS.md` · architecture: `Docs/Architecture.md` · gameplay vocabulary: `Docs/CoreDesignConcepts.md` · Apple HIG: `Docs/AppleNativeGuidelines.md` · art: `Docs/ArtPipeline.md` · content: `Docs/ContentPipeline.md` · setup: `README.md`

## Product & Architecture

- iOS iPhone-first, portrait-only (`project.yml`). Swift 6.0 / SwiftUI; iOS 26.0. Public Apple APIs for StoreKit, GameKit, privacy, cloud, etc.; update docs with App Store/privacy implications.
- SwiftUI for shell/menus/overlays and battle presentation. Rules/state separate from rendering; small owned types; abstract after repetition. Planned local Swift packages: see `Docs/Architecture.md`.
- Product tabs: Play, Heroes, Inventory, Homestead, Options (`Docs/CoreDesignConcepts.md`). Code: `AppTab.collection` = Heroes+Pets+Inventory hub; also `.play`, `.homestead`, `.search`, `.options`. UI tests tap `"Homestead"`, not enum raw values.
- Codebase: `App/` · `Features/` · `Battle/BattleRun.swift` (app shell) · `State/` stores · `Models/` · `Content/` · `Packages/{TrinketCore,TrinketContent,BattleEngine}/` · `TrinketTests/` · `TrinketUITests/`.
- Generated: `Trinket/Generated/*` (art/music), `Packages/TrinketContent/.../Generated/*` (catalogs) — edit manifests, `./Scripts/generate.sh` (`Docs/ContentPipeline.md`, `Docs/Architecture.md`). Shared domain types: `Packages/TrinketCore/`. `Raw Assets/` source-only. Don't hand-edit generated output, `.DerivedData/`, build products, or `.swiftlint.yml` severity (without reason here).

## Battle Module

Combat rules live in `Packages/BattleEngine/` (`BattleState`, effect handlers, simulator, `Combatant`, roster/enemy catalogs). App shell: `Trinket/Battle/BattleRun.swift`, `ActiveBattleConfiguration.swift`, `BattleVictorySummary.swift`.

Key patterns:
- Effects are value-type structs conforming to `BattleEffectHandler`; lookup by `EffectKind` dictionary in `BattleState`.
- Test determinism: use `BattleStateTestFactory.makeBattle(...)` in `BattleEngineTests` (seed 0) instead of raw `BattleState(...)`.

## Apple-Native Product Rules

- System SwiftUI, SF Symbols, Dynamic Type, accessibility, semantic colors/materials. Major UI: `Docs/AppleNativeGuidelines.md`. Swift API Design Guidelines; testably separate models, rules, rendering, persistence, platform services.
- `TabView` top-level only; `NavigationStack`, sheets, alerts, menus, `ToolbarItem` for detail. Portrait, thumb-reachable; VoiceOver, Reduce Motion, contrast, Dynamic Type.
- Chrome via `TrinketDesign`; no ad-hoc `.buttonStyle`, materials, capsules, simulated glass. Native glass on iOS 26+ with fallbacks. `Toggle` modes, `Button` actions; `controlSize`, `buttonBorderShape`, `Label`, semantic styles.
- Bypass: `// UIStyleCheck: allow - <reason>` (same/preceding line); prefer `TrinketDesign`. Raw styling lives in `Trinket/DesignSystem/`.

## Git Workflow

- Work on `main` unless the user explicitly requests a feature branch.
- Commit locally when work is complete or before testing.
- Do **not** `git push` unless the user explicitly asks.
- Do **not** create or update pull requests unless the user explicitly asks.

## Commands & Verification

All under `./Scripts/`: `generate.sh` (validates manifests, content codegen, XcodeGen), `assert-generated-output.sh`, `validate-manifests.sh`, `build.sh`, `test.sh`, `test-iterate.sh`, `test-deploy.sh`, `test-timing.sh`, `format.sh`, `lint.sh`, `ci-locally.sh`, `run-simulator.sh`, `prepare-art-assets.sh`, `capture-screenshot.sh`, `check-ui-style.sh` (`test.sh style`). `test.sh` records per-run timings to `.DerivedData/TestResults/timing-log.jsonl`; `./Scripts/test-timing.sh` reports recent runs and slow-test hotspots without re-running tests. XcodeGen, `xcodebuild`, XCTest, SwiftFormat, SwiftLint. `test.sh` runs `generate.sh` unless `--no-build`; `--no-build` is only for rerunning an unchanged, already-built test binary and refuses stale sources. `ci-locally.sh`/`test-deploy.sh` always `generate.sh` first. After `project.yml` changes, `generate.sh` before build/test.

| Change | Check |
|--------|-------|
| One-screen layout | `build.sh` or `run-simulator.sh` |
| Styling | `check-ui-style.sh` + smoke |
| Rules/models | `test.sh unit <Tests>`; full unit mode also runs `TrinketCore`, `TrinketContent`, and `BattleEngine` package tests |
| Multi-step UI | `test-iterate.sh <SmokeClass> [ExhaustiveClass]` |
| Pre-push | `ci-locally.sh` |
| Pre-merge | `test-deploy.sh` |

**Test tiers** (fast → thorough):

| Tier | Command | What runs | When |
|------|---------|-----------|------|
| Unit | `test.sh unit` | All `TrinketTests` | Every logic change |
| UI smoke | `test.sh smoke` | `Smoke.xctestplan` — 9 `Smoke*` UI classes only (~2 min) | Tab/screen edits, pre-push |
| Targeted UI | `test.sh ui <Class>` | One UI class | Focused UI iteration |
| Full UI | `test.sh ui` | All `TrinketUITests` including exhaustive flows | Pre-merge |
| Integration | `test.sh all` | `Integration.xctestplan` — unit + all UI in one run | Nightly / manual |

`Smoke.xctestplan` is **UI smoke only** (not unit tests). `Unit.xctestplan` and `FullUI.xctestplan` back `test.sh unit` and `test.sh ui`. `test-deploy.sh` runs style → unit → full UI once (smoke is a subset, not rerun).

Iteration: **unit** → **smoke class** → **exhaustive class** before merge. Example: `./Scripts/test-iterate.sh SmokeCollectionTests TabNavigationUITests`. Exact rerun without rebuild: `./Scripts/test.sh ui SmokeCollectionTests --no-build`. Unit tests in `TrinketTests/` plus `Packages/{TrinketCore,TrinketContent,BattleEngine}/Tests/`; `./Scripts/test.sh unit BattleStateTests[/testMethod]` runs app tests only — battle rule tests live in `BattleEngineTests`. `BattleSimulator` in `Packages/BattleEngine/`. Focused diffs; `ci-locally.sh` before push.
- **Speed Tip**: Avoid `ci-locally.sh` or `test-deploy.sh` during active development. Compile with `build.sh` or run simulator previews.

## Unit Tests

Framework: **XCTest** + `@testable import Trinket`. Mirror production folders (`Battle/`, `Persistence/`, `State/`, etc.). SwiftUI `Features/*` views are covered by UI smoke/deploy tests, not unit tests.

### Shared helpers (`TrinketTests/Support/`)

| Helper | Use for |
|--------|---------|
| `SaveTestSupport` | Temp save directories, `PlayerSaveFileStore` / `PlayerSaveStore` factories |
| `AppTestSupport` | `makeAppState` with injectable `sync`, `fileStore`, `userDefaults` |
| `CombatantFixtures` | Minimal combatants and abilities for handler/model tests |
| `BattleStateTestFactory` | **Always** use for RNG-sensitive battle tests (`rngSeed: 0`) |
| `BattleTestFixtures` | Integration tick helpers, `standardParty`, effect predicates |

### Conventions

- **Naming:** `test<Behavior>When<Condition>` — e.g. `testLocalMutationSchedulesDebouncedUpload`.
- **Battle rules:** `BattleStateTestFactory.makeBattle(...)` instead of raw `BattleState(...)`.
- **Handler tests:** dispatch through `EffectHandlers.all`; use `CombatantFixtures` for setup.
- **Store tests:** `@MainActor` class, `SaveTestSupport.makeTempDirectory`, mutate → reload from disk → assert.
- **Async/debounce:** inject short intervals in production init params; poll in tests — never `Task.sleep` for multi-second production delays.
- **Golden paths:** pin outcome counters (ticks, health, victory/defeat); assert event *semantics* (status kinds, milestones) rather than full log fingerprints.
- **Ability descriptions:** `AbilityDescriptionFormatterTests` guards catalog prose; prefer focused examples over duplicating full catalog loops elsewhere.
- **Homestead rewards:** test `PlayerHomesteadState.adjustedMaterialRewards` directly, then stage-completion integration for end-to-end grants.
- **Battle UI flow:** use `BattleRun.outcome` and `BattleRun.makeVictorySummary()` — keep outcome logic out of SwiftUI views.
- **Launch screens:** collection deep links live on `AppState.initialCollectionCombatantDetail` / `initialCollectionItemID`, not `AppEnvironment.shared` in views.
- **Content invariants:** loop `GameContent` for catalog tests (unique IDs, art refs, stage→enemy links).
- **Do not unit-test:** log prose formatting details, `TrinketDesign` styling, AVFoundation playback, real CloudKit I/O.

### Definition of done (new features)

1. Rules/models → at least one focused unit test.
2. New `Player*Store` API → write-through persistence test.
3. New catalog content → invariant test in the matching `*CatalogTests` class.
4. New user flow → `accessibilityIdentifier` + one smoke UI test.
5. Run `./Scripts/test.sh unit <TestClass>` before commit.

## UI Tests

**Smoke** (`TrinketUITests/Smoke/`): lean per-screen checks via `Smoke.xctestplan`. **Exhaustive** (`Collection/`, `Battle/`, `Search/`): multi-step journeys only in `test.sh ui` / `test-deploy.sh`. One assertion theme per smoke method; split at ~20 lines. `TestLaunchArg` + `LaunchScreen` (`AppTypes.swift`), parsed in `AppEnvironment`; helpers `allForScreen`, `allForBattle`, `completedStages`. Args: `-reset-state` (default), `-launch-screen` (`hero:`, `pet:`, `item:`, `options`, `battle` starts stage 1-1), `-selectedTab` (`play`, `collection`, `homestead`, `search`, `options`; `heroes`/`pets`/`inventory`→`.collection`), `-completed-stages` (comma IDs). Smoke classes `Smoke*` (files match class names). `.accessibilityIdentifier` like `"Stage 1-1 Node"`, `"Battle Button"`; use `assertExists`. `Player*Store`/UserDefaults; keep `-reset-state` unless testing persistence.
