# Feature-local guide

Feature work belongs in the matching `Features/<flow>/` folder. Read `Docs/AgentContext/swiftui-features.md` before editing.

- Use shared state through the environment; feature views may own transient local `@State` but not app or session stores.
- Use `TrinketDesignSystem` chrome, colors, and shared views from `Trinket/Shared/` before creating a local abstraction. Never introduce one-off `Color` / system palette literals — extend the design system instead.
- Add/reuse a stable `AccessibilityID` test selector and a smoke test for a new player flow. Do not add custom accessibility semantics or accessibility-setting branches; follow PD-007.
- Use the root task-scoped workflow for verification. During feature iteration, run only the affected smoke target (`./Scripts/test.sh smoke <SmokeClass>`), narrowing to `<SmokeClass>/<testMethod>` when one method directly owns the behavior; leave global style and broader suites to pre-push or CI. Bare `./Scripts/test.sh smoke` is the Homestead pre-push canary, not a generic feature check.
