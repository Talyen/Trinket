# SwiftUI feature context

Use for tabs, screens, navigation, shared views, design-system polish, and accessibility identifiers.

Play, Collection, Homestead, and Options screens live in `Trinket/Features/`.
Shared game-specific views, presentation models, accessibility IDs, and artwork/frame
support live in `Packages/TrinketFeatureSupport`. App and Play orchestration lives in
`Packages/TrinketAppState`; Battle owns its own context card and package. The app
target composes these modules but packages never import the app.

Use current SwiftUI: `NavigationStack`, modern `Tab`, sheets, `ToolbarItem`, adaptive text roles (`.primary` / `.secondary`), `@Observable` environment state, and `@Bindable`. Prefer the narrowest environment owner for a subtree (`BattleSession`, encounter sessions) over whole `AppState` when the view only needs that slice. Use `TrinketDesign`, `.trinketSurface`, `.trinketMaterial`, `.trinketGlassChip`, `TrinketHeroScrim`, and `.trinketOnArtText`; do not create local substitutes or one-off colors (`Color.green`, `.white`, `Color(red:)`, app-bundle `Color("…")`). New colors belong in `DesignColors.xcassets` via the design system. Use `TrinketMotion` for reusable fluid motion. File-level `@ViewBuilder` helpers that touch DesignSystem modifiers must be `@MainActor` (or methods on a `View`) so Swift 6 concurrency accepts them.

Give a view the narrowest owner it needs: a Play mode coordinator
(`JourneyPlayMode`, `LabyrinthPlayMode`, `SpiresPlayMode`, `EncounterPlayMode`),
`PlaySession` only for shell navigation/victory routing, a specific encounter session,
`BattleSession`, or a Battle read lane. Play screens take mode owners for orchestration
and `PlayerSaveStore` for save slices — do not reintroduce slice facades on
`PlaySession`. Do not pass `AppState` through a feature tree when explicit values and
actions suffice.

New player flows need a stable `AccessibilityID` from `TrinketFeatureSupport` (or an
existing appropriate one) for UI automation. Add or extend a smoke/exhaustive UI test
only when the keep/drop rubric in `Docs/Platform/Testing.md` applies (shell/entry,
state-changing journey, or one-owner safety invariant). IDs are test selectors, not a
promise of custom VoiceOver semantics; do not add accessibility labels, hints, values,
grouping, traits, or accessibility-setting branches without an explicit product
decision. Feature views use UI coverage only when that rubric passes; a view change
alone does not require a test. Verify with path-scoped
`./Scripts/verify-changed.sh --isolate --paths …`. Policy and path-scoped tiers:
`Docs/Platform/Testing.md` and `Docs/AgentContext/ci-and-project-generation.md`. Read
`TrinketUITests/README.md` only for launch args, screen helpers, or test speed.
