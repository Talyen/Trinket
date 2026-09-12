# Feature-local guide

Feature work belongs in the matching `Features/<flow>/` folder. Feature UI and state wiring must conform to the [SwiftUI features guide](../../Docs/AgentContext/swiftui-features.md).

- Use shared state through the environment; feature views may own transient local `@State` but not app or session stores. Name `@Environment(PlayerSaveStore.self)` bindings `playerSave` — never `appState`.
- Artwork, hitch prevention, and tab prewarm: [UI performance guide](../../Docs/AgentContext/ui-performance.md). That guide owns tab first-layout, the retained `BattleView` overlay, and bar-hiding rules; the root guardrail owns approval for changing the prepared-artwork strategy.

[Homestead layout](../../Docs/Product/Homestead.md). [Battle layout](../../Packages/TrinketBattleFeature/README.md) ([hand size](../../Packages/BattleEngine/README.md)).
