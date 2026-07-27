# Feature-local guide

Feature work belongs in the matching `Features/<flow>/` folder. Feature UI and state wiring must conform to `Docs/AgentContext/swiftui-features.md`.

- Use shared state through the environment; feature views may own transient local `@State` but not app or session stores. Scope observability to the smallest subtree that needs it.
- Visual chrome and colors come from `TrinketDesignSystem` and shared views in `Trinket/Shared/`. Never introduce one-off `Color` / system palette literals — extend the design system instead.
- `@ViewBuilder` helpers must compile under Swift 6 strict concurrency (file-level helpers that call DesignSystem / view modifiers need `@MainActor`, or live as methods on a `View`).
- New player flows need stable accessibility identifiers suitable for smoke tests. Add or extend UI smoke only when the keep/drop rubric in `Docs/Platform/Testing.md` applies. Do not add custom accessibility semantics or accessibility-setting branches; follow PD-007.
- Feature changes must pass path-scoped verification before handoff.

## Homestead UX contract

- Art-led overview: full-bleed hero, compact seven-resource wallet, and Play Mode–style category cards (Farming / Crafting / Alchemy / Training / Arcana) with tier-sum constructed progress — tapping a category pushes its project list.
- Category list keeps hero (category art) + wallet, drops the in-content category header, and lists that category’s projects; project rows stay tappable in every state (including prerequisite-locked) and push native `NavigationStack` detail while retaining the tab bar.
- Detail shows a single vertical tier path plus a persistent build/upgrade footer; build/upgrade is immediate with no confirmation dialog.
- Dense content stays on solid semantic surfaces; keep glass/material for floating chrome and the detail footer.

## Battle UX contract

See `Packages/BattleEngine/README.md` for hand size, art ratios, and chrome constraints that the battle UI must honor.
