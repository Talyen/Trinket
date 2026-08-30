# Feature-local guide

Feature work belongs in the matching `Features/<flow>/` folder. Feature UI and state wiring must conform to the [SwiftUI features guide](../../Docs/AgentContext/swiftui-features.md).

- Use shared state through the environment; feature views may own transient local `@State` but not app or session stores. Scope observability to the smallest subtree that needs it. Name `@Environment(PlayerSaveStore.self)` bindings `playerSave` — never `appState`.
- Visual chrome and colors come from `TrinketDesignSystem`. Never introduce one-off color literals.
- `@ViewBuilder` helpers that call DesignSystem modifiers need `@MainActor`, or live as methods on a `View`.
- New player flows need stable accessibility identifiers. Add or extend UI smoke only when the keep/drop rubric in [Testing](../../Docs/Platform/Testing.md) applies. Accessibility baseline: [PD-007](../../Docs/Product/Decisions.md).
- Feature changes must pass path-scoped verification before handoff.
- Artwork, hitch prevention, and tab prewarm: [SwiftUI features guide](../../Docs/AgentContext/swiftui-features.md) and [`PreparedArtworkCache`](../../Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift). Do not convert `prepareAndPin` to on-demand `Image(name)`; see that guide for `HiddenTabPrewarm`/`BattleView` overlay and bar-hiding rules.

[Homestead layout](../../Docs/Product/Homestead.md). [Battle layout](../../Packages/TrinketBattleFeature/README.md) ([hand size](../../Packages/BattleEngine/README.md)).
