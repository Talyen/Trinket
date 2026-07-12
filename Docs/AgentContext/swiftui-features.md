# SwiftUI feature context

Use for tabs, screens, navigation, shared views, design-system polish, and accessibility identifiers.

Product screens live in `Trinket/Features/`, shared game-specific views in `Trinket/Shared/`, app routing in `Trinket/App/` and `Trinket/State/`, and visual presentation helpers in `Trinket/Models/`. Feature views may depend on packages, state, shared, and models; state must not depend on views.

Use current SwiftUI: `NavigationStack`, modern `Tab`, sheets, `ToolbarItem`, adaptive text roles (`.primary` / `.secondary`), `@Observable` environment state, and `@Bindable`. Use `TrinketDesign`, `.trinketSurface`, `.trinketMaterial`, `.trinketGlassChip`, `TrinketHeroScrim`, and `.trinketOnArtText`; do not create local substitutes or one-off colors (`Color.green`, `.white`, `Color(red:)`, app-bundle `Color("…")`). New colors belong in `DesignColors.xcassets` via the design system. Use `TrinketMotion` for reusable fluid motion.

New player flows need an `AccessibilityID` (or an existing appropriate one) and one smoke UI test. Feature views are UI-tested, not unit-tested. Run `./Scripts/test.sh style`, `./Scripts/check-ui-style.sh`, and `./Scripts/test.sh smoke`; use a targeted smoke class for iteration. Read `TrinketUITests/README.md` only for launch args, screen helpers, or test speed.
