# Trinket agent guide

Portrait-first iOS fantasy turn-based card combat. Read this file first; then read **one** relevant card in `Docs/AgentContext/`. Do not load broad architecture or testing docs unless the card routes you there.

## Non-negotiable platform rules

- iOS 26.0 minimum, Swift 6 strict concurrency, Xcode 26+, SwiftUI, SwiftData.
- Do not add availability checks for pre-iOS-26 releases or UIKit bridges when SwiftUI has a first-party solution.
- New state uses `@Observable`, `@Environment(Type.self)`, and `@Bindable`; never add `NavigationView`, `ObservableObject`, `@StateObject`, or `@Published`.
- Use `TrinketDesignSystem` for reusable chrome. Do not hand-roll materials, glass, or reusable button styles in feature views.
- Packages never import the `Trinket` app. `TrinketDesignSystem` depends on `TrinketCore` only.
- App layers: `BattleShell/` must not import `Features/`; `State/` must not import feature views; `Models/` must not import `State/` or `Features/`.
- Keep `BattleState` and `PlayerSaveStore` thin; put rules in handlers/engines, store slices, extensions, or value types.

## Generated and protected paths

- Edit manifests, never `Packages/**/Generated/`; run `./Scripts/generate.sh` after content or `project.yml` edits, and `./Scripts/generate.sh --assets` after art/music/SFX/cinematic input edits. App and test source roots use Xcode synchronized folders, so ordinary Swift additions/deletions do not require project-file edits or regeneration.
- Never hand-edit processed assets/resources, `.DerivedData/`, `.tools/`, or `Trinket.xcodeproj/project.pbxproj`. Use `project.yml` and generation.
- Review only the expected generated diff after generation; for asset work also verify processed paths with `git status --short`.
- Do not edit `CHANGELOG.md` per commit or treat audit documents as a backlog. Avoid drive-by changes.

## Skills

- [Apple Design](Docs/Skills/apple-design/SKILL.md) — fluid motion, materials,
  typography, accessibility, and gesture feedback.

## Start with the smallest relevant context card

| Work | Read |
|---|---|
| Battle rules, cards, effects | `Docs/AgentContext/battle.md` |
| Save data, stores, CloudKit | `Docs/AgentContext/persistence.md` |
| Catalogs, TSVs, art/audio/video pipelines | `Docs/AgentContext/content-and-manifests.md` |
| SwiftUI screen or navigation | `Docs/AgentContext/swiftui-features.md` |
| Music or SFX playback | `Docs/AgentContext/audio.md` |
| Project generation, CI, or test commands | `Docs/AgentContext/ci-and-project-generation.md` |
| Product behavior question | `Docs/Product/Decisions.md` |

Use `./Scripts/changed-source-summary.sh` before a handoff or review. It reports authored changes and the focused context/test route without dumping generated or binary files. Use `./Scripts/verify-changed.sh --dry-run` to preview the minimal verification plan, then `./Scripts/verify-changed.sh` to run it.

## Verification

- Any Swift change: `./Scripts/test.sh style` plus focused package/unit/smoke coverage.
- Unit/package targets use Swift Testing; `TrinketUITests` uses XCTest only.
- Package rules/models: `./Scripts/test-package.sh <Package>`.
- App orchestration: `./Scripts/test.sh unit <Class>`.
- Tab/screen UI: `./Scripts/test.sh smoke` (local canary; `smoke-full` and `ui` are CI/pre-merge tiers).
- Styling: `./Scripts/check-ui-style.sh`, plus smoke when UI changes.
- Pre-push: `./Scripts/ci-locally.sh`; pre-merge: `./Scripts/test-deploy.sh`.

Wrapper verification that can run XcodeGen must be sequential: `test.sh` may generate the project, so do not run wrapper tests in parallel. Without Xcode 26/simulator, run applicable generation, generated-output, boundary, style, and CI-gate checks; clearly state skipped build/test work.
`SKIP_GENERATE=1` is an explicit escape hatch for CI or iteration after generation; do not use it to bypass an unknown or stale project/spec state.

## Further reference

- Repo graph, persistence, and generation: `Docs/Platform/Architecture.md`
- Test ownership and definition of done: `Docs/Platform/Testing.md`
- Battle migration: `Docs/Plans/BattleCardCombatMigration.md`
- UI HIG/chrome: `Packages/TrinketDesignSystem/README.md`, `Docs/Platform/iOS26AppleReference.md`
- Commits, release, and gates: `Scripts/README.md`

Local work stays on `main` and is not pushed or PR'd unless requested. Commits use `<type>(<scope>): <imperative subject>` and include `User-Facing: yes | no`; see `Scripts/README.md`.
