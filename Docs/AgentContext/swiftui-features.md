# SwiftUI feature context

Use for tabs, screens, navigation, shared views, design-system polish, and accessibility identifiers.

Play, Collection, Homestead, and Options screens live in `Trinket/Features/`.
Shared game-specific views, presentation models, accessibility IDs, and artwork/frame
support live in `Packages/TrinketFeatureSupport`. App and Play orchestration lives in
`Packages/TrinketAppState`; Battle owns its own context card and package. The app
target composes these modules but packages never import the app.

Artwork on the first paint of a tab, sheet, or push is decoded into
`PreparedArtworkCache` at launch (or the owning surface's `.task`) and **pinned**
so deferred catalog warmup cannot evict it. `Image.preparedAsset` falling through
to `Image(name)` sync-decodes on that frame — that is the hitch path, not a
memory win. Do not convert this to on-demand loading. Transient battle and
Collection pins still release when that lifecycle ends; Collection re-keys its
pin task when shelf combatants change so newly unlocked heroes stay hitch-free.
Memory targets and enforcement: [PerformanceInvestigationPlaybook.md](../Platform/PerformanceInvestigationPlaybook.md) Artwork Budgets.

The four tab roots first-layout under the launch cover, including the tab that
is already selected. Play uses the longer first-layout budget for the hidden
battlefield; other tabs use a shorter budget. When exactly one run is prepared,
Play first-layouts a paused `BattleView` in the overlay at opacity 0. Keep
`TabView` mounted during battle and hide the tab bar; tearing it down
recolds Collection, Homestead, and Options. Do not lazy-build detail bodies
to win a presentation frame — that moves the hitch onto scrolling. Do not
drop the prepared overlay mount; pause its TimelineViews until
`lifecyclePhase` is `.active` instead. Do not push campaign (or other
navigation destinations) under the cover — those views are destroyed on pop,
and a leftover path lands the player off the mode hub.

Use current SwiftUI: `NavigationStack`, modern `Tab`, sheets, `ToolbarItem`, adaptive text roles (`.primary` / `.secondary`), `@Observable` / `@Environment` / `@Bindable`, two-parameter `onChange`. Do not reintroduce `NavigationView`, `ObservableObject` / `@Published`, or single-parameter `onChange`. Keep the root tab bar fully expanded. Hidden toolbar chrome on Battle and detail-hero screens is an intentional art-forward choice.

Prefer the narrowest environment owner for a subtree (`BattleSession`, encounter sessions) over whole `AppState` when the view only needs that slice. Chrome, colors, glass, and typography: [TrinketDesignSystem README](../../Packages/TrinketDesignSystem/README.md). Feature views must not call raw `.glassEffect` / `.buttonStyle(.glass*)` or invent one-off colors. Use `TrinketMotion` for reusable fluid motion. File-level `@ViewBuilder` helpers that touch DesignSystem modifiers must be `@MainActor` (or methods on a `View`).

Give a view the narrowest owner it needs: a Play mode coordinator, `PlaySession` only for shell navigation/victory routing (including battle activation via `play.battle`), a specific encounter session, `BattleSession`, or a Battle read lane. Play's campaign/explore stack (`PlayBrowsingStack`) must not observe `BattleSession`; the battle overlay (`PlayBattleOverlay`) is a separate observation scope so map chrome does not rebuild on combat ticks. Shell battle routing observes `PlaySession.battle`; do not reintroduce parallel handles or slice facades (see [battle-runtime.md](battle-runtime.md)). Do not pass `AppState` through a feature tree when explicit values and actions suffice.

New player flows need a stable `AccessibilityID` from `TrinketFeatureSupport` (or an
existing appropriate one). Add UI coverage only when the keep/drop rubric in
`Docs/Platform/Testing.md` identifies a shipping outcome that lower tiers cannot own;
a view change alone does not require a test. IDs are selectors, not substitutes for
player-facing semantics: preserve native labels and add a concise label/value when a
custom control is ambiguous. Accessibility uses basic explicit semantics by policy (PD-014,
[Decisions](../Product/Decisions.md)): keep what SwiftUI provides for free and do not
add Reduce Motion, Dynamic Type re-layout, or contrast accommodation branches. Use `TrinketUITests/README.md` only for
launch args, screen helpers, and speed rules.
