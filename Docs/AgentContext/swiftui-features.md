# SwiftUI feature context

Use for tabs, screens, navigation, shared views, design-system polish, and accessibility identifiers.

Play, Collection, Homestead, and Options screens live in `Trinket/Features/`.
Shared game-specific views, presentation models, accessibility IDs, and artwork/frame
support live in `Packages/TrinketFeatureSupport`. App and Play orchestration lives in
`Packages/TrinketAppState`; Battle owns its own context card and package. The app
target composes these modules but packages never import the app.

Use current SwiftUI: `NavigationStack`, modern `Tab`, sheets, `ToolbarItem`, adaptive text roles (`.primary` / `.secondary`), `@Observable` / `@Environment` / `@Bindable`, two-parameter `onChange`. Do not reintroduce `NavigationView`, `ObservableObject` / `@Published`, or single-parameter `onChange`. Keep the root tab bar fully expanded. Hidden toolbar chrome on Battle and detail-hero screens is an intentional art-forward choice.

Prefer the narrowest environment owner for a subtree (`BattleSession`, encounter sessions) over whole `AppState` when the view only needs that slice. Chrome, colors, glass, and typography: [TrinketDesignSystem README](../../Packages/TrinketDesignSystem/README.md). Feature views must not call raw `.glassEffect` / `.buttonStyle(.glass*)` or invent one-off colors. Use `TrinketMotion` for reusable fluid motion. File-level `@ViewBuilder` helpers that touch DesignSystem modifiers must be `@MainActor` (or methods on a `View`).

Give a view the narrowest owner it needs: a Play mode coordinator, `PlaySession` only for shell navigation/victory routing (including battle activation via `play.battle`), a specific encounter session, `BattleSession`, or a Battle read lane. Play's campaign/explore stack (`PlayBrowsingStack`) must not observe `BattleSession`; the battle overlay (`PlayBattleOverlay`) is a separate observation scope so map chrome does not rebuild on combat ticks. Shell battle routing observes `PlaySession.battle`; do not reintroduce parallel handles or slice facades (see [battle-runtime.md](battle-runtime.md)). Do not pass `AppState` through a feature tree when explicit values and actions suffice.

New player flows need a stable `AccessibilityID` from `TrinketFeatureSupport` (or an
existing appropriate one). Add UI coverage only when the keep/drop rubric in
`Docs/Platform/Testing.md` identifies a shipping outcome that lower tiers cannot own;
a view change alone does not require a test. IDs are selectors, not substitutes for
player-facing semantics: preserve native labels and add a concise label/value when a
custom control is ambiguous. Accessibility is bare-minimum by policy (PD-007,
[Decisions](../Product/Decisions.md)): keep what SwiftUI provides for free and do not
add Reduce Motion, Dynamic Type re-layout, or contrast accommodation branches. Use `TrinketUITests/README.md` only for
launch args, screen helpers, and speed rules.
