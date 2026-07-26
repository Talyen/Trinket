# Feature-local guide

Feature work belongs in the matching `Features/<flow>/` folder. Read `Docs/AgentContext/swiftui-features.md` before editing.

- Use shared state through the environment; feature views may own transient local `@State` but not app or session stores.
- Use `TrinketDesignSystem` chrome, colors, and shared views from `Trinket/Shared/` before creating a local abstraction. Never introduce one-off `Color` / system palette literals — extend the design system instead.
- File-level `@ViewBuilder` helpers that call DesignSystem / view modifiers must be `@MainActor` (or live as methods on a `View`). Free nonisolated helpers fail Swift 6 concurrency under `build-for-testing` even when style is clean.
- Add/reuse a stable `AccessibilityID` test selector for a new player flow. Add or extend UI smoke only when the keep/drop rubric in `Docs/Platform/Testing.md` applies (shell/entry, state-changing journey, or one-owner safety invariant). Do not add custom accessibility semantics or accessibility-setting branches; follow PD-007.
- Verify with path-scoped `./Scripts/verify-changed.sh --isolate --paths …`. Policy and path-scoped tiers: `Docs/Platform/Testing.md` and `Docs/AgentContext/ci-and-project-generation.md`.

## Homestead UX contract

- Art-led overview: full-bleed hero, compact seven-resource wallet, and Play Mode–style category cards (Farming / Crafting / Alchemy / Training / Arcana) with tier-sum constructed progress — tapping a category pushes its project list.
- Category list keeps hero (category art) + wallet, drops the in-content category header, and lists that category’s projects; project rows stay tappable in every state (including prerequisite-locked) and push native `NavigationStack` detail while retaining the tab bar.
- Detail shows a single vertical tier path plus a persistent build/upgrade footer; build/upgrade is immediate with no confirmation dialog.
- Dense content stays on solid semantic surfaces; keep glass/material for floating chrome and the detail footer.

## Battle UX contract

See `Packages/BattleEngine/README.md` for hand size, art ratios, and chrome constraints that the battle UI must honor.
