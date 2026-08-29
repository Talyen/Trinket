# Feature-local guide

Feature work belongs in the matching `Features/<flow>/` folder. Feature UI and state wiring must conform to the [SwiftUI features guide](../../Docs/AgentContext/swiftui-features.md).

- Use shared state through the environment; feature views may own transient local `@State` but not app or session stores. Scope observability to the smallest subtree that needs it. Name `@Environment(PlayerSaveStore.self)` bindings `playerSave` — never `appState`.
- Visual chrome and colors come from `TrinketDesignSystem`. Never introduce one-off color literals.
- `@ViewBuilder` helpers that call DesignSystem modifiers need `@MainActor`, or live as methods on a `View`.
- New player flows need stable accessibility identifiers. Add or extend UI smoke only when the keep/drop rubric in [Testing](../../Docs/Platform/Testing.md) applies. Accessibility baseline: [PD-007](../../Docs/Product/Decisions.md).
- Feature changes must pass path-scoped verification before handoff.
- Do not change Collection / Homestead / Play artwork `prepareAndPin` into first-paint `Image(name)` loads. That preload is hitch prevention, not leftover cache.
- First-layout the four tab roots under the launch cover via `HiddenTabPrewarm` (hidden `ZStack` at `opacity 0.001` / `scale 0.01`, not by flipping `selectedTab`). Play keeps the longer budget for the overlay battlefield; other tabs use the shorter secondary budget. Play first-layouts a paused overlay `BattleView` for a single prepared run. Do not push navigation destinations under the cover — they do not stay mounted, and a leftover path skips the mode hub. Do not destroy `TabView` during battle to hide the tab bar — that recolds every tab. Hide the bar instead.
- Re-key Collection detail artwork pins when shelf combatants change so newly unlocked heroes do not hitch on the zoom+sheet frame.

[Homestead layout](../../Docs/Product/Homestead.md). [Battle layout](../../Packages/TrinketBattleFeature/README.md) ([hand size](../../Packages/BattleEngine/README.md)).
