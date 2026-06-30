# AGENTS.md

Guidance for agents on Trinket: portrait-first iOS fantasy idle auto-battler.

## When To Read What

- Workflow/scripts/style: `AGENTS.md` · gameplay vocabulary: `Docs/CoreDesignConcepts.md` · Apple HIG: `Docs/AppleNativeGuidelines.md` · art: `Docs/ArtPipeline.md` · setup: `README.md`

## Product & Architecture

- iOS iPhone-first, portrait-only (`project.yml`). Swift/SwiftUI/SpriteKit; iOS 26.0, Swift 5.0. Public Apple APIs for StoreKit, GameKit, privacy, cloud, etc.; update docs with App Store/privacy implications.
- SwiftUI for shell/menus/overlays; SpriteKit for 2D loops, sprites, physics, particles, collision. Rules/state separate from rendering; small owned types; abstract after repetition.
- Product tabs: Play, Heroes, Inventory, Homestead, Options (`Docs/CoreDesignConcepts.md`). Code: `AppTab.collection` = Heroes+Pets+Inventory hub; also `.play`, `.homestead`, `.search`, `.options`. UI tests tap `"Homestead"`, not enum raw values.
- Codebase: `App/` · `Features/` · `Battle/` · `State/` stores · `Models/` · `Content/GameContent.swift` · `DesignSystem/TrinketDesign` · `Shared/` · `TrinketTests/` · `TrinketUITests/Smoke/` + `{Collection,Battle,Search}/`.
- Generated: `Trinket/Generated/*`, curated `Assets.xcassets` — edit `ArtManifest/curated-assets.tsv`, `./Scripts/prepare-art-assets.sh` (`Docs/ArtPipeline.md`). `Raw Assets/` source-only. Don't hand-edit generated output, `.DerivedData/`, build products, or `.swiftlint.yml` severity (without reason here).

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

All under `./Scripts/`: `generate.sh`, `build.sh`, `test.sh`, `test-iterate.sh`, `test-deploy.sh`, `format.sh`, `lint.sh`, `ci-locally.sh`, `run-simulator.sh`, `prepare-art-assets.sh`, `capture-screenshot.sh`, `check-ui-style.sh` (`test.sh style`). XcodeGen, `xcodebuild`, XCTest, SwiftFormat, SwiftLint. `test.sh` runs xcodegen unless `--fast`; `ci-locally.sh`/`test-deploy.sh` always `generate.sh` first. After `project.yml` changes, `generate.sh` before build/test.

| Change | Check |
|--------|-------|
| One-screen layout | `build.sh` or `run-simulator.sh` |
| Styling | `check-ui-style.sh` + smoke |
| Rules/models | `test.sh unit <Tests>` |
| Multi-step UI | `test-iterate.sh <Smoke> <FullUI>` |
| Pre-push | `ci-locally.sh` |
| Pre-merge | `test-deploy.sh` |

Tiers: **smoke** → **targeted full-UI** (`TestClass[/testMethod]`) → **full UI** (deploy). **perf** (`test.sh perf`) runs `XCTMeasure` guards in `TrinketTests/Performance/`; excluded from `unit`/`ci-locally.sh`, included in `test-deploy.sh`. No committed baselines yet — metrics are recorded in the `.xcresult` for trend review. No `test.sh ui`/`all` during iteration. Example: `test-iterate.sh SmokeCollectionTests Collection/TabNavigationUITests --fast`. Unit tests in `TrinketTests/{Battle,Journey,Item}/`; `./Scripts/test.sh unit BattleStateTests[/testMethod]`. `BattleSimulator` in `Trinket/Battle/BattleSimulator.swift`. Focused diffs; `ci-locally.sh` before push.

## UI Tests

Smoke in `TrinketUITests/Smoke/`; deploy flows in `{Collection,Battle,Search}/`. One assertion per method; split at ~20 lines. `TestLaunchArg` + `LaunchScreen` (`AppTypes.swift`), parsed in `AppEnvironment`; helpers `allForScreen`, `allForTab`, `completedStages`. Args: `-reset-state` (default), `-launch-screen` (`hero:`, `pet:`, `item:`, `options`, `battle`), `-selectedTab` (`play`, `collection`, `homestead`, `search`, `options`; `heroes`/`pets`/`inventory`→`.collection`), `-completed-stages` (comma IDs). No `play:`/Search screen deep links. Smoke classes `Smoke*` (file may differ). `.accessibilityIdentifier` like `"Stage 1-1 Node"`, `"Battle Button"`; use `assertExists`. `Player*Store`/UserDefaults; keep `-reset-state` unless testing persistence.
