# Feature-local guide

Feature work belongs in the matching `Features/<flow>/` folder. Read `Docs/AgentContext/swiftui-features.md` before editing.

- Use state through the environment; do not make feature views state owners.
- Use `TrinketDesignSystem` chrome and shared views from `Trinket/Shared/` before creating a local abstraction.
- Add/reuse an `AccessibilityID` and a smoke test for a new player flow.
- Run `./Scripts/test.sh style`, `./Scripts/check-ui-style.sh`, and `./Scripts/test.sh smoke` for UI changes.
