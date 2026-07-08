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
- Use `NavigationStack`, modern `Tab`, sheets, `ToolbarItem`, semantic colors.
- Use SwiftData (`@Model`) for persistence — see `TrinketPersistence`.
- Route chrome through `TrinketDesign` / `.trinketSurface` / `.trinketMaterial` / `.trinketGlassChip` in `TrinketDesignSystem`.
- When unsure, **grep the repo** before inventing a pattern: app state → `AppState`; chrome → `TrinketDesignSystem`; battle rules → `BattleEngine`; catalogs → `TrinketContent` / manifests.

“Fallbacks” in design docs mean **accessibility** (Reduce Transparency / Reduce Motion), not older iOS support.

### Style guardrails

`./Scripts/check-ui-style.sh` flags raw `.regularMaterial` / `.thinMaterial` / `.ultraThinMaterial`, raw `.buttonStyle(.glass|glassProminent|bordered|borderedProminent)`, `.toggleStyle(.button)`, and fixed `.frame(width:)` / `.frame(height:)` inside text buttons. Bypass with `// UIStyleCheck: allow - <reason>` on the same or preceding line. Otherwise route reusable chrome through `Packages/TrinketDesignSystem/`. Prefer fixing SwiftLint violations over new `swiftlint:disable`. Major UI guidance: `Docs/Design/AppleNativeGuidelines.md`.

### Module & hub boundaries

- **Packages** must not import the `Trinket` app. `TrinketDesignSystem` → `TrinketCore` only (not `BattleEngine` or `TrinketContent`).
- **App layers:** `BattleShell/` ↛ `Features/`; `State/` ↛ feature views; `Models/` ↛ `State/` or `Features/`. Full graph: `Docs/Architecture.md`.
- **Hub containment:** keep `BattleState` and `PlayerSaveStore` thin — put new logic in handlers/engines, `Player*Store` slices, or `BattleState+*.swift` / value-type models (Architecture “Extension policy”).

### Hard do-not-touch

- Hand-edit `Generated/`, `.DerivedData/`, or `.tools/`
- Edit processed `Trinket/Assets.xcassets` or `Trinket/Resources/Music` except via `./Scripts/generate.sh --assets`
- Edit `CHANGELOG.md` per commit — `./Scripts/release.sh` owns it
- Implement `Docs/Roadmap.md` (`R-###`) unless the user cites an entry
- Treat `Docs/Audits/*Audit.md` as standing backlog, or append run results into an audit file
- Drive-by refactors, unsolicited markdown, or scope beyond the asked task

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
| Pre-push | `./Scripts/ci-locally.sh` (gate + unit + smoke) |
| Pre-merge | `./Scripts/test-deploy.sh` (gate + unit + full UI) |
| One-screen layout check | `./Scripts/build.sh` or `./Scripts/run-simulator.sh` |

Fast iteration: `--no-build` after a fresh build; `./Scripts/test-iterate.sh <SmokeClass> [ExhaustiveClass]` for UI loops. Avoid `ci-locally.sh` / `test-deploy.sh` during active coding — prefer `build.sh` or filtered unit/smoke.

### Toolchain ladder (cloud / no Xcode 26)

Local and CI expect **Xcode 26+**. Without the simulator toolchain:

1. Land correct source/docs changes.
2. Run what you can: `./Scripts/generate.sh`, `./Scripts/assert-generated-output.sh`, `./Scripts/check-module-boundaries.sh`, `./Scripts/check-ui-style.sh`, `./Scripts/ci-gate.sh`.
3. Skip `build.sh` / `test.sh` / simulator work — state that clearly in the commit/PR body.
4. When Xcode 26 + simulator **are** present, `build.sh` / `test.sh` (or the Task Router row) are mandatory before claiming the change is verified.

## When To Read What

| Need | Doc |
|------|-----|
| Repo map, packages, tabs, generate, persistence, hubs | `Docs/Architecture.md` |
| Setup / first run | `README.md` |
| Gameplay vocabulary | `Docs/Design/CoreDesignConcepts.md` |
| Apple HIG / native UI | `Docs/Design/AppleNativeGuidelines.md` |
| Visual foundation | `Docs/Design/StyleGuide/AppVisualFoundation.md` |
| iOS 26 APIs / stack notes | `Docs/Platform/` |
| Content / art / music pipelines | `ContentManifest/README.md`, `ArtManifest/README.md`, `MusicManifest/README.md` |
| SFX manifest | `SoundManifest/sfx.tsv` (prepare via `generate.sh --assets`) |
| Battle test ownership | `Packages/BattleEngine/Tests/README.md` |
| UI test launch args / speed | `TrinketUITests/README.md` |
| Release / changelog / commit contract detail | `Scripts/README.md` |
| Speculative ideas | `Docs/Roadmap.md` (`R-###`) — only when cited |
| Audits | `Docs/Audits/README.md` — run only when cited |
| Liquid Glass migration phases | `Docs/Platform/LiquidGlassMigrationPlan.md` — only when asked |

## Packages (quick)

Six local packages under `Packages/`. Product packages with unit schemes: `TrinketCore`, `TrinketContent`, `BattleEngine`, `TrinketPersistence`, `TrinketDesignSystem`. **`TrinketTestSupport`** is fixtures-only — no product API and no `test-package.sh` scheme.

- **Battle rules:** `Packages/BattleEngine/` (`BattleState`, effect handlers, simulator). App shell: `Trinket/State/BattleSession.swift`, `Trinket/BattleShell/`.
- **Generated output:** edit manifests (and custom content under `TrinketContent` when applicable), then `./Scripts/generate.sh` — never hand-edit `Generated/`.

Product tabs: Play → Collection → Homestead → Options. Collection owns in-tab `.searchable` for Heroes/Pets/Items (see Architecture). UI tests tap labels like `"Homestead"` and `"Collection"`, not enum raw values. Accessibility IDs: prefer `Trinket/Shared/AccessibilityID.swift` over inventing new string literals.

## Git Workflow

| Context | Branching | Push / PR |
|---------|-----------|-----------|
| **Local** (default) | Work on `main`. Do not create feature branches unless the session explicitly requires it. | Commit on `main`. Do **not** push or open PRs unless the user asks. |
| **Cloud agent / CI harness** | Follow session instructions (feature branches, PR tools, push). | Allowed when the session says so. |

If session instructions conflict with the local default, **session wins**. Explicit user instructions (e.g. “push to main”) override both.

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
- Full release workflow, hooks (`SKIP_TRINKET_PREPUSH=1`), and parsers: `Scripts/README.md`. Fast gate without tests: `./Scripts/ci-gate.sh`.

## Commands & Verification

Scripts under `./Scripts/` (XcodeGen, `xcodebuild`, Swift Testing, XCTest, SwiftFormat, SwiftLint). `test.sh` runs `generate.sh` then builds then tests (unless `--no-build`). Pin format/lint with `./Scripts/ensure-ci-tools.sh`.

| Gate | Runs |
|------|------|
| `ci-gate.sh` | generate → assert → boundaries → Swift Testing check → style → release-notes validate |
| `ci-locally.sh` | `ci-gate.sh` → unit → smoke (+ timing budgets) — **pre-push** |
| `test-deploy.sh` | gate-style checks → unit → full UI — **pre-merge** |
| GitHub `pr.yml` | gate → unit + smoke (parallel) on `macos-26` |
| GitHub `ci.yml` (main) | gate → unit + full UI (parallel) on `macos-26` |

| Tier | Command | When |
|------|---------|------|
| Unit | `test.sh unit` | Every logic change |
| Unit (filtered) | `test.sh unit <Class>` | Focused app logic (`TrinketTests` only) |
| Package unit | `test-package.sh <Package>` | Focused package logic |
| UI smoke | `test.sh smoke` | Tab/screen edits, pre-push (`TrinketUITests/Smoke/`) |
| Targeted UI | `test.sh ui <Class>` | Focused UI iteration |
| Full UI | `test.sh ui` | Pre-merge (includes exhaustive) |
| Integration | `test.sh all` | Nightly / manual |

Iteration before merge: **unit** → **smoke class** → **exhaustive class**. Keep diffs focused.

## Unit Tests

**Swift Testing only** in `TrinketTests/` and package test targets (`import Testing`). **XCTest** only in `TrinketUITests/`. Enforced by `./Scripts/check-swift-testing-migration.sh`.

Mirror production folders under `TrinketTests/`. SwiftUI `Features/*` views → UI smoke/deploy, not unit tests.

**Ownership:** Battle → `Packages/BattleEngine/Tests/README.md`. Catalogs → `TrinketContentTests`. Stores → `TrinketPersistenceTests`. App shell → `TrinketTests/` only.

**Fixtures:** prefer `TrinketTestSupport` (`CombatantFixtures`, `SaveTestSupport`, battle parties). App suites: `AppTestContext` / `AppTestSupport`. Persistence: `PersistenceTestContext`. Battle RNG: always `BattleStateTestFactory.makeBattle(...)` with `rngSeed: 0`; dispatch via `EffectHandlers.all`.

### Conventions

- **Naming:** `@Test func behaviorWhenCondition()` — no `test` prefix required.
- **Assertions:** `#expect`; `try #require` / `#require` to unwrap; `Issue.record` for unconditional failures.
- **Parameterization:** `@Test(arguments:)` for catalog loops and symmetric keyword variants.
- **Lifecycle:** Prefer `@Suite` on package tests. In `TrinketTests`, `struct …Tests` + `@Test` is fine. Use `@MainActor` when UI/layout/store isolation requires it. Use `final class` + `init() throws` only for teardown ownership (`AppTestContext` / `PersistenceTestContext`).
- **Stores:** mutate → reload from disk → `#expect`.
- **Async/debounce:** inject short intervals in production inits; poll in tests — never `Task.sleep` for multi-second production delays.
- **Events:** pin outcome counters; assert event *semantics*, not full log fingerprints.
- **Do not unit-test:** log prose (except a few representative formatter cases), `TrinketDesign` styling, AVFoundation playback, real CloudKit I/O.

### Definition of done (new features)

1. Rules/models → focused unit test in the owning package.
2. New `Player*Store` API → write-through persistence test in `TrinketPersistenceTests`.
3. New catalog content → invariant test in the matching `*CatalogTests` (`TrinketContentTests`).
4. New `EffectKind` → registry parity + `EffectHandlersApplyTests`; thin integration only for multi-effect combos.
5. New app orchestration on `AppState` / `BattleSession` → focused `TrinketTests` test.
6. New user flow → `AccessibilityID` (or existing id) + one smoke UI test.
7. Run `./Scripts/test.sh unit` (full, unfiltered) before commit when package code changed (toolchain permitting).

## UI Tests

Smoke lives in `TrinketUITests/Smoke/` (`Smoke.xctestplan`). Exhaustive journeys under `Play/`, `Collection/`, `Battle/` — `test.sh ui` / `test-deploy.sh` only. Page objects: `TrinketUITests/Support/Screens/`.

Default smoke args: `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`. Prefer `-launch-screen` / `-selectedTab` deep links; avoid Play-map scroll loops (`-completed-stages` / `-map-scroll-target`). Assert with `assertExists` on ids from `AccessibilityID` / existing identifiers.

Full launch-arg catalog, speed rules, and mid-battle guidance: **`TrinketUITests/README.md`**.
