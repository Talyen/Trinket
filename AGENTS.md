# AGENTS.md

Canonical agent operating manual for Trinket — any coding agent or harness (not IDE-specific). Portrait-first iOS fantasy idle auto-battler.

Repo map, modules, persistence, generate: **`Docs/Architecture.md`**. Testing conventions: **`Docs/Testing.md`**. This file is workflow, contracts, and verification — not a second architecture or testing guide.

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

## Contracts

- **Style:** Route reusable chrome through `Packages/TrinketDesignSystem/`; `./Scripts/check-ui-style.sh` enforces materials/button styles. Prefer fixing SwiftLint over new `swiftlint:disable`. UI guidance: `Docs/Design/AppleNativeGuidelines.md`. Fluid motion: Cursor skill `.cursor/skills/apple-design/SKILL.md` (apply via SwiftUI / `TrinketMotion`, not web CSS).
- **Packages** must not import the `Trinket` app. `TrinketDesignSystem` → `TrinketCore` only (not `BattleEngine` or `TrinketContent`).
- **App layers:** `BattleShell/` ↛ `Features/`; `State/` ↛ feature views; `Models/` ↛ `State/` or `Features/`. Full graph: `Docs/Architecture.md`.
- **Hub containment:** keep `BattleState` and `PlayerSaveStore` thin — handlers/engines, `Player*Store` slices, or `BattleState+*.swift` / value-type models (Architecture “Extension policy”).

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
| Tab / screen UI | `./Scripts/test.sh smoke` (Homestead canary; **not** `smoke-full` / `ui` / `ci-locally` during active coding) |
| Styling | `./Scripts/check-ui-style.sh` (+ `test.sh smoke` if UI changed) |
| Pre-push | `./Scripts/ci-locally.sh` |
| Pre-merge | `./Scripts/test-deploy.sh` |
| One-screen layout check | `./Scripts/build.sh` or `./Scripts/run-simulator.sh` |

Fast iteration: `--no-build` after a fresh build; `./Scripts/test.sh smoke <SmokeClass>` or `test-iterate.sh` for one smoke class. Preferred full-unit path: `./Scripts/build-for-testing.sh && ./Scripts/test.sh unit --no-build`. During active coding prefer `build.sh`, `test.sh unit`, and bare `test.sh smoke` — `smoke-full` is CI-only unless debugging a smoke failure. Gate/tier details: `Scripts/README.md`.

**No Xcode 26 / simulator:** land correct source/docs; run `generate.sh`, `assert-generated-output.sh`, `check-module-boundaries.sh`, `check-ui-style.sh`, `ci-gate.sh` as applicable; skip `build.sh` / `test.sh`; state skips in the commit/PR body. When the toolchain is present, router verification is mandatory before claiming done.

## When To Read What

| Need | Doc |
|------|-----|
| Repo map, packages, tabs, generate, persistence, hubs | `Docs/Architecture.md` |
| Unit / UI test conventions, DoD detail | `Docs/Testing.md` |
| UI launch args / speed | `TrinketUITests/README.md` |
| Setup / first run | `README.md` |
| Release / commit contract / gates | `Scripts/README.md` |
| Apple HIG / native UI | `Docs/Design/AppleNativeGuidelines.md` |
| Gameplay vocabulary | `Docs/Design/CoreDesignConcepts.md` |
| Content / art / music pipelines | `ContentManifest/README.md`, `ArtManifest/README.md`, `MusicManifest/README.md` |

Cited-only (Roadmap, Audits, Identity, Liquid Glass, Platform notes): open only when the user cites them or the task requires them — see Hard do-not-touch.

## Git & commits

| Context | Branching | Push / PR |
|---------|-----------|-----------|
| **Local** (default) | Work on `main`. No feature branches unless the session requires it. | Commit on `main`. Do **not** push or open PRs unless the user asks. |
| **Cloud agent / CI harness** | Follow session instructions. | Allowed when the session says so. |

Session instructions override the local default; explicit user instructions override both.

Commits: `<type>(<scope>): <imperative subject ≤72 chars>` plus optional bullets, then `User-Facing: yes | no` (and `Breaking:` if needed). Types: `feat`, `fix`, `perf`, `refactor`, `content`, `style`, `test`, `ci`, `chore`, `docs`. Imperative subjects without a type prefix are OK. Full template, hooks (`SKIP_TRINKET_PREPUSH=1`), and parsers: **`Scripts/README.md`**.

## Testing (summary)

Swift Testing for unit/package targets; XCTest for `TrinketUITests/` only. New features: follow the definition of done in **`Docs/Testing.md`** (package/unit coverage, persistence write-through, catalog invariants, AccessibilityID + smoke for new flows). Run `./Scripts/test.sh unit` before commit when package code changed (toolchain permitting). UI smoke canary: `./Scripts/test.sh smoke`.
