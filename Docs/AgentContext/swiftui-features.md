# SwiftUI feature context

Use for tabs, screens, navigation, shared views, design-system polish, and accessibility identifiers.

Product screens live in `Trinket/Features/`, shared game-specific views in `Trinket/Shared/`, app routing in `Trinket/App/` and `Trinket/State/`, and visual presentation helpers in `Trinket/Models/`. Feature views may depend on packages, state, shared, and models; state must not depend on views.

Use current SwiftUI: `NavigationStack`, modern `Tab`, sheets, `ToolbarItem`, adaptive text roles (`.primary` / `.secondary`), `@Observable` environment state, and `@Bindable`. Use `TrinketDesign`, `.trinketSurface`, `.trinketMaterial`, `.trinketGlassChip`, `TrinketHeroScrim`, and `.trinketOnArtText`; do not create local substitutes or one-off colors (`Color.green`, `.white`, `Color(red:)`, app-bundle `Color("…")`). New colors belong in `DesignColors.xcassets` via the design system. Use `TrinketMotion` for reusable fluid motion.

New player flows need a stable `AccessibilityID` (or an existing appropriate one) for UI automation and one smoke UI test. IDs are test selectors, not a promise of custom VoiceOver semantics; do not add accessibility labels, hints, values, grouping, traits, or accessibility-setting branches without an explicit product decision. Feature views are UI-tested, not unit-tested. For a small feature iteration, run only `./Scripts/test.sh smoke <SmokeClass>` for the closest affected screen or flow, narrowing to `<SmokeClass>/<testMethod>` when one method directly owns it; if none covers it, add or update one focused smoke test. Leave global style, bare smoke, full unit, `smoke-full`, and exhaustive UI suites to pre-push or CI. Read `TrinketUITests/README.md` only for launch args, screen helpers, or test speed.
