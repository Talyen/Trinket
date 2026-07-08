# AGENTS.md

Canonical agent operating manual for Trinket — any coding agent or harness (not IDE-specific). Portrait-first iOS fantasy idle auto-battler.

Repo map, module graph, persistence, and generate pipeline: **`Docs/Architecture.md`**. This file is workflow, contracts, and verification — not a second architecture doc.

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

- Use `@Observable` + `@Environment(Type.self)` + `@Bindable` for app state (`Trinket/State/AppState.swift`, `Trinket/App/ContentView.swift`).
- Use `NavigationStack`, modern `Tab` (including `role: .search`), sheets, `ToolbarItem`, semantic colors.
- Use SwiftData (`@Model`) for persistence — see `TrinketPersistence`.
- Route chrome through `TrinketDesign` / `.trinketSurface` / `.trinketMaterial` / `.trinketGlassChip` in `TrinketDesignSystem`.
- When unsure, **grep the repo** before inventing a pattern: app state → `AppState`; chrome → `TrinketDesignSystem`; battle rules → `BattleEngine`; catalogs → `TrinketContent` / manifests.

“Fallbacks” in design docs mean **accessibility** (Reduce Transparency / Reduce Motion), not older iOS support.

### Style guardrails

`./Scripts/check-ui-style.sh` flags:

- Raw materials: `.background` / `.fill` with `.regularMaterial`, `.thinMaterial`, or `.ultraThinMaterial`.
- Raw button/toggle styles: `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)`, `.buttonStyle(.bordered)`, `.buttonStyle(.borderedProminent)`, `.toggleStyle(.button)`.
- Fixed interactive dimensions inside buttons: `.frame(width:)` / `.frame(height:)` paired with text/fonts.

Bypass with `// UIStyleCheck: allow - <reason>` on the same or preceding line. Otherwise route reusable chrome through `Packages/TrinketDesignSystem/`. Major UI guidance: `Docs/Design/AppleNativeGuidelines.md`.

### Module boundaries (one-liner)

Packages must not import the `Trinket` app. `TrinketDesignSystem` → `TrinketCore` only (not `BattleEngine` or `TrinketContent`). Full graph and app-layer import rules: `Docs/Architecture.md`.

## Task → Command Router

| Task | Command / action |
|------|------------------|
| Content / ability TSV or catalog Swift under `TrinketContent` | `./Scripts/generate.sh` then stage `Generated/` |
| Art, music, or SFX manifests | `./Scripts/generate.sh --assets` |
| `project.yml` change | `./Scripts/generate.sh` before build/test |
| Package rules/models | `./Scripts/test-package.sh <Package>` |
| App orchestration (`AppState`, `BattleSession`, …) | `./Scripts/test.sh unit <Class>` |
| Tab / screen UI | `./Scripts/test.sh ui Smoke<Area>Tests` |
| Styling | `./Scripts/check-ui-style.sh` (+ smoke if UI changed) |
| Pre-push | `./Scripts/ci-locally.sh` |
| Pre-merge | `./Scripts/test-deploy.sh` |
| One-screen layout check | `./Scripts/build.sh` or `./Scripts/run-simulator.sh` |

Fast iteration: `--no-build` after a fresh build; `./Scripts/test-iterate.sh <SmokeClass> [ExhaustiveClass]` for UI loops. Avoid `ci-locally.sh` / `test-deploy.sh` during active coding — prefer `build.sh` or filtered unit/smoke.

**Toolchain note:** Local and CI expect **Xcode 26+**. Cloud or remote agents without that toolchain should still land correct source/docs changes; run generate/lint/boundary scripts when available, and treat `build.sh` / `test.sh` as mandatory when the simulator toolchain is present.

## When To Read What

| Need | Doc |
|------|-----|
| Repo map, packages, tabs, generate, persistence | `Docs/Architecture.md` |
| Setup / first run | `README.md` |
| Gameplay vocabulary | `Docs/Design/CoreDesignConcepts.md` |
| Apple HIG / native UI | `Docs/Design/AppleNativeGuidelines.md` |
| Visual foundation | `Docs/Design/StyleGuide/AppVisualFoundation.md` |
| iOS 26 APIs / stack notes | `Docs/Platform/` (`README.md`, audits, Liquid Glass plan) |
| Content / art / music pipelines | `ContentManifest/README.md`, `ArtManifest/README.md`, `MusicManifest/README.md` |
| SFX manifest | `SoundManifest/sfx.tsv` (no README yet; prepare via `generate.sh --assets`) |
| Battle test ownership | `Packages/BattleEngine/Tests/README.md` |
| Release / changelog | `Scripts/README.md` |
| Speculative ideas | `Docs/Roadmap.md` (`R-###`) — **do not implement** unless the user cites an entry |
| Point-in-time audits | `Docs/Audits/*` — **not** standing requirements unless cited |
| Liquid Glass migration phases | `Docs/Platform/LiquidGlassMigrationPlan.md` — follow only when the user asks |

## Packages (quick)

Six local packages under `Packages/`. Product packages with unit schemes (five): `TrinketCore`, `TrinketContent`, `BattleEngine`, `TrinketPersistence`, `TrinketDesignSystem`. **`TrinketTestSupport`** is fixtures-only (`CombatantFixtures`, `SaveTestSupport`, battle parties) — no product API and no `test-package.sh` scheme.

- **Battle rules:** `Packages/BattleEngine/` (`BattleState`, effect handlers, simulator). App shell: `Trinket/State/BattleSession.swift`, `Trinket/BattleShell/`.
- **Generated output:** edit manifests (and custom content under `TrinketContent` when applicable), then `./Scripts/generate.sh` — never hand-edit `Generated/`, `.DerivedData/`, or build products. SFX: `SoundManifest/sfx.tsv` → `prepare-sfx-assets.sh` (via `--assets`).
- Don't edit `.swiftlint.yml` severity without reason here. Prefer fixing violations over new `swiftlint:disable`; treat disable count as a ratchet.

Product tabs (Play / Collection / Homestead / Search / Options) and `AppTab` mapping: `Docs/Architecture.md`. UI tests tap labels like `"Homestead"` and `"Collection"`, not enum raw values.

## Git Workflow

**Harness-aware:**

| Context | Branching | Push / PR |
|---------|-----------|-----------|
| **Local** (default) | Work on `main`. Do not create feature branches unless the session explicitly requires it. | Commit on `main`. Do **not** push or open PRs unless the user asks. |
| **Cloud agent / CI harness** | Follow session instructions (feature branches, PR tools, push). | Allowed when the session says so. |

If session instructions conflict with the local default, **session wins**.

## Commit Messages

```
<type>(<scope>): <imperative subject ≤72 chars>

- <notable change>
- <another change>

User-Facing: yes | no
Breaking: <description if only applicable>
```

- **Types:** `feat`, `fix`, `perf`, `refactor`, `content`, `style`, `test`, `ci`, `chore`, `docs`
- Imperative subjects without a type prefix are acceptable.
- **`User-Facing: yes`** when players would notice; **`no`** for CI/style/refactor/tooling.
- Do **not** edit `CHANGELOG.md` per commit — `./Scripts/release.sh` generates it at release time.
- Optional hook: `git config core.hooksPath .githooks` (advisory via `./Scripts/validate-commit-msg.sh`).

## Commands & Verification

Scripts live under `./Scripts/`. Tooling: XcodeGen, `xcodebuild`, XCTest, Swift Testing, SwiftFormat, SwiftLint. `test.sh` runs `generate.sh` then builds then tests (unless `--no-build`). Timings: `.DerivedData/TestResults/timing-log.jsonl`; report with `./Scripts/test-timing.sh`.

**Groups** (see `Scripts/` for the full set): **Codegen** (`generate.sh`, manifest/asset preparers, assert-generated) · **Quality** (`format.sh`, `lint.sh`, `check-ui-style.sh`, `check-module-boundaries.sh`, `check-swift-testing-migration.sh`) · **Build/test** (`build.sh`, `test.sh`, `test-package.sh`, `test-iterate.sh`, `ci-locally.sh`, `test-deploy.sh`, …) · **Release** (`release.sh`, release-notes helpers).

**Gates:**

| Script / CI | Runs |
|-------------|------|
| `ci-locally.sh` | generate → assert-generated → boundaries → Swift Testing migration check → style → validate release notes → unit → unit timing budget → smoke |
| `test-deploy.sh` | generate → assert-generated → boundaries → style → validate release notes → unit → full UI |
| GitHub `pr.yml` | gate → unit + smoke (parallel) |
| GitHub `ci.yml` (main) | gate → unit + full UI (parallel) |

**Test tiers** (fast → thorough):

| Tier | Command | What runs | When |
|------|---------|-----------|------|
| Unit | `test.sh unit` | `TrinketTests` + five package schemes (sequential) | Every logic change |
| Unit (filtered) | `test.sh unit <Class>` | App tests only (`TrinketTests/<Class>`) | Focused app logic |
| Package unit | `test-package.sh <Package>` | One product package scheme | Focused package logic |
| UI smoke | `test.sh smoke` | `Smoke.xctestplan` — **5** `Smoke*` classes (~2 min) | Tab/screen edits, pre-push |
| Targeted UI | `test.sh ui <Class>` | One UI class | Focused UI iteration |
| Full UI | `test.sh ui` | All `TrinketUITests` including exhaustive flows | Pre-merge |
| Integration | `test.sh all` | `Integration.xctestplan` — unit + all UI | Nightly / manual |

`Smoke.xctestplan` is **UI smoke only**. `Unit.xctestplan` / `FullUI.xctestplan` back `test.sh unit` / `test.sh ui`. `test-deploy.sh` runs full UI once (smoke is a subset, not rerun).

Iteration before merge: **unit** → **smoke class** → **exhaustive class**. Keep diffs focused; run `ci-locally.sh` before push when the toolchain is available.

## Unit Tests

**Swift Testing only** in `TrinketTests/` and package test targets (`import Testing`, `@Test`, `#expect` / `#require`). **XCTest** remains only for `TrinketUITests/`. Unit targets must not import XCTest — enforced by `./Scripts/check-swift-testing-migration.sh` (CI / `ci-locally.sh` ratchet).

Mirror production folders under `TrinketTests/`. SwiftUI `Features/*` views are covered by UI smoke/deploy tests, not unit tests.

**Ownership:** Battle rules → `Packages/BattleEngine/Tests/README.md`. Catalog invariants → `Packages/TrinketContent/Tests/`. Persistence stores → `TrinketPersistenceTests`. App shell orchestration → `TrinketTests/` only.

### Shared helpers

| Helper | Location | Use for |
|--------|----------|---------|
| `AppTestContext` | `TrinketTests/Support/` | Per-suite temp save dir + `UserDefaults` + `makeAppState` |
| `PersistenceTestContext` | `TrinketPersistenceTests/Support/` | Temp directory lifecycle for store roundtrips |
| `SaveTestSupport` | `Packages/TrinketTestSupport/` | Temp save dirs and `PlayerSaveStore` factories |
| `AppTestSupport` | `TrinketTests/Support/` | Stateless `makeAppState` when caller owns `directoryURL` |
| `CombatantFixtures` / `BattlePartyFixtures` | `Packages/TrinketTestSupport/` | Minimal combatants, abilities, parties |
| `BattleStateTestFactory` | `Packages/BattleEngine/Tests/BattleEngineTests/` | **Always** for RNG-sensitive battle tests (`rngSeed: 0`) |
| `BattleTestFixtures` | `Packages/BattleEngine/Tests/BattleEngineTests/Support/` | Integration tick helpers, `standardParty`, effect predicates |

Prefer importing **`TrinketTestSupport`** over duplicating fixtures.

### Conventions

- **Naming:** `@Test func behaviorWhenCondition()` — no `test` prefix required.
- **Assertions:** `#expect` for checks; `try #require` / `#require` to unwrap and halt; `Issue.record` for unconditional failures.
- **Parameterization:** `@Test(arguments:)` for catalog loops and symmetric keyword variants.
- **Lifecycle:** Prefer `@Suite` on package tests (existing norm). In `TrinketTests`, `struct …Tests` + `@Test` is fine; add `@Suite` when it helps discovery/grouping. Use `@MainActor` on suite or test when UI/layout/store isolation requires it. Use `final class` + `init() throws` only when teardown ownership needs a reference type (`AppTestContext` / `PersistenceTestContext`).
- **Main actor:** Swift Testing does not run sync tests on `@MainActor` by default — annotate when needed.
- **Battle:** `BattleStateTestFactory.makeBattle(...)`; dispatch handlers through `EffectHandlers.all`; thin integration only (see BattleEngine Tests README).
- **Stores:** mutate → reload from disk → `#expect`.
- **Async/debounce:** inject short intervals in production inits; poll in tests — never `Task.sleep` for multi-second production delays.
- **Golden paths / events:** pin outcome counters; assert event *semantics*, not full log fingerprints.
- **Do not unit-test:** log prose (except a few representative formatter cases), `TrinketDesign` styling, AVFoundation playback, real CloudKit I/O.

### Definition of done (new features)

1. Rules/models → focused unit test in the owning package.
2. New `Player*Store` API → write-through persistence test in `TrinketPersistenceTests`.
3. New catalog content → invariant test in the matching `*CatalogTests` (`TrinketContentTests`).
4. New `EffectKind` → registry parity + `EffectHandlersApplyTests`; thin integration only for multi-effect combos.
5. New app orchestration on `AppState` / `BattleSession` → focused `TrinketTests` test.
6. New user flow → `accessibilityIdentifier` + one smoke UI test.
7. Run `./Scripts/test.sh unit` (full, unfiltered) before commit when package code changed (toolchain permitting).

## UI Tests

**Smoke** (`TrinketUITests/Smoke/`, `Smoke.xctestplan`): five classes — `SmokeBattleTests`, `SmokeCollectionTests`, `SmokeHeroDetailTests`, `SmokeHomesteadTests`, `SmokePlayTests`. Lean per-screen checks; one assertion theme per method; split at ~20 lines.

**Exhaustive** (`TrinketUITests/Play/`, `Collection/`, `Battle/`, `Search/`): multi-step journeys in `test.sh ui` / `test-deploy.sh` only.

**Support** (`TrinketUITests/Support/Screens/`): page objects (`PlayScreen`, `TabBar`, …).

**Launch args:** `TestLaunchArg` in `TrinketUITests/Support/TrinketUITestCase.swift`; parsed by `AppEnvironment` (`LaunchScreen` in `AppTypes.swift`). Helpers: `allForScreen`, `allForTab`, `allForBattle`, `completedStages`, `mapScrollTarget`.

Default smoke args: `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`. Additional:

- `-launch-screen` (`hero:`, `pet:`, `item:`, `options`, `battle` → stage 1-1)
- `-selectedTab` (`play`, `collection`, `homestead`, `search`, `options`; `heroes`/`pets`/`inventory` → `.collection`)
- `-completed-stages`, `-map-scroll-target`, `-battle-tick-interval`
- `-disable-audio`, `-appearance` (see `AppEnvironment.parse`)

Use `.accessibilityIdentifier` values like `"Stage 1-1 Node"`, `"Battle Button"`; assert with `assertExists`. Keep default launch args unless testing persistence.

**Speed:**

- Prefer `-launch-screen` / `-selectedTab` deep links; do not re-navigate a screen launch args already opened.
- Avoid long Play-map scrolls; use `-completed-stages` or `-map-scroll-target`.
- Filter inventory/search with `replaceText` instead of grid scroll loops.
- Mid-battle exhaustive tests: enter via Play map, not `-launch-screen battle` with very fast ticks.
- UI tests run serially on a single simulator by default. Hotspots: `./Scripts/test-timing.sh report --top 30`.
