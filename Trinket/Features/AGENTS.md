# Feature-local guide

Feature work belongs in the matching `Features/<flow>/` folder. Read `Docs/AgentContext/swiftui-features.md` before editing.

- Use shared state through the environment; feature views may own transient local `@State` but not app or session stores.
- Use `TrinketDesignSystem` chrome, colors, and shared views from `Trinket/Shared/` before creating a local abstraction. Never introduce one-off `Color` / system palette literals — extend the design system instead.
- Add/reuse a stable `AccessibilityID` test selector and a smoke test for a new player flow. Do not add custom accessibility semantics or accessibility-setting branches; follow PD-007.
- Use the root task-scoped workflow for style and focused checks. For UI changes, also run the affected smoke class (`./Scripts/test.sh smoke <Class>`); bare `./Scripts/test.sh smoke` is only the local Homestead canary.
