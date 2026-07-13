# Homestead Cinematic Overview and Tier-Path Redesign

## Summary

Redesign Homestead as an art-led, native SwiftUI experience while preserving the existing nine-project progression, resource economy, build/upgrade persistence, categories, and bonuses.

Success means:

- Homestead opens with full-bleed artwork, a compact seven-resource wallet, and all nine projects grouped by their live categories.
- Project rows clearly distinguish prerequisite-locked, unlocked-unbuilt, built, upgrade-ready, and completed states.
- Tapping any project—including locked projects—pushes a native detail destination while retaining the tab bar and standard back navigation.
- Detail screens present the complete three-tier progression path and a persistent build/upgrade footer.
- The interface is visual-first and targets the supported portrait layout with native SwiftUI controls and visible labels; comprehensive accessibility support is out of scope per PD-007.

## Experience Specification

### Homestead overview

- Replace the large navigation title, recommended-project card, horizontal wallet, and progressive project filtering with:
  1. A full-width 4:3 Homestead hero extending beneath the status/navigation area.
  2. A bottom gradient scrim with a large system-serif “Homestead” title.
  3. A compact, solid semantic wallet containing all seven resources.
  4. Farming, Crafting, and Research sections containing every project in manifest order.
- Use the existing shared overscroll contract: artwork expands directly during pull-down and the compact navigation title cross-fades in after the overlaid title scrolls away.
- Use system serif only for display and section titles; retain SF typography for body text, balances, statuses, and buttons.
- Keep dense content on semantic solid surfaces. Reserve material for floating navigation and the persistent detail footer rather than stacking glass panels.
- Lay out the wallet as four columns using the product’s supported visual layout.
- Use existing SF Symbols and resource colors; do not add custom resource icons.

### Project rows

- Use each project’s generated thumbnail, title, one effect line, and a trailing state affordance. Do not show tier counts on the overview.
- Apply these exact presentation rules:
  - **Prerequisite-locked:** muted/grayscale thumbnail and text, tier-one effect shown, trailing lock, row remains tappable.
  - **Unlocked but unbuilt:** readable subdued color, tier-one effect shown, trailing build symbol only when currently affordable; otherwise use a chevron.
  - **Built:** show the current tier’s active effect, never the next tier’s effect.
  - **Upgrade-ready:** replace the chevron with `arrow.up.circle.fill` only when the next tier exists and is immediately affordable.
  - **Completed:** show the final active effect with a completion symbol; row remains tappable.
- Give rows immediate press-down feedback through a design-system-owned pressed state.
- Preserve live content assignments: all nine projects remain under their current manifest categories, including Alchemy Lab under Research.

### Project detail

- Replace the modal sheet with value-based `NavigationStack` destinations. Retain the system tab bar and native back affordance.
- Use the selected project’s full artwork as an overscrolling hero, with its title over a legibility gradient and a collapsing inline navigation title.
- Place the same seven-resource wallet below the hero so balances remain available while evaluating costs.
- For prerequisite-locked projects, show a compact prerequisite callout before the tier path. Keep all tier names and effects readable rather than hiding future information.
- Replace the current separate “Current Effect,” “Next Upgrade,” and “Requirements” sections with one vertical tier path:
  - One node per manifest tier, using the project symbol.
  - Completed tiers use the project tint with a restrained glow.
  - The next unlocked tier uses an accented outline; affordability strengthens its treatment but does not change its position.
  - Later or prerequisite-locked tiers remain muted with lock treatment.
  - Connector segments visually distinguish completed and future progress.
  - Each node’s title and complete effect copy appear alongside it.
- Add a persistent bottom safe-area footer above the tab bar:
  - Show the next tier’s resource icons and required quantities.
  - Tint shortages semantically and show the required quantities visually.
  - Label tier one as **Build** and later tiers as **Upgrade**.
  - Keep the button disabled when prerequisites or resources are insufficient, with the visible state explaining the action.
  - At maximum tier, preserve the footer footprint with a noninteractive checkmark and **Complete** state.
- Build and upgrade remain immediate, with no confirmation dialog. On success:
  - Stay on the detail screen.
  - Update wallet balances with numeric transitions.
  - Advance the tier path and footer to the next tier.
  - Animate the completed node with a critically damped emphasis.
  - Fire the existing success haptic when enabled.
- Preserve the existing error alert for persistence failures.

## Implementation Changes and Interfaces

- Refactor the Homestead feature into overview hero, adaptive resource wallet, grouped project rows, tier-path detail, and persistent action-footer components. Remove the featured-project presentation and retire reveal-only helpers once they have no consumers.
- Extend `HomesteadProjectStatus` or an adjacent internal presentation value type with explicit row state, overview effect, next-tier state, affordability, and completion mappings. Keep these as derived UI state; do not duplicate or persist them.
- Extend the shared hero scroll shell with a configurable semantic background mode so Homestead can reuse existing overscroll, toolbar-title, and focal-crop behavior without creating a second scroll implementation.
- Add opt-in design-system interfaces for:
  - System-serif display and section typography roles.
  - A semantic pressable navigation-row style.
  - Homestead motion presets using approximately `response: 0.35`, `dampingFraction: 1.0`.
- Add accessibility identifiers for the wallet, category sections, tier nodes, prerequisite callout, and footer action states while retaining existing screen, row, and detail identifiers.
- Add a final art-manifest entry with ID `homestead`, asset name `bg_homestead`, source `Raw Assets/Homestead/Homestead.jpeg`, and a curated focal point. Run the asset generator rather than editing processed assets.
- Until the clean hero source exists, resolve the overview hero through an explicit fallback to existing Wheat Field art. Do not crop artwork from the phone-composite mockup.
- No persistence models, save migrations, gameplay rules, tier costs, category assignments, or public content schemas change.

## Test Plan

- Add Swift Testing coverage for pure presentation mapping:
  - Locked projects expose the tier-one effect.
  - Unbuilt projects distinguish affordable build-ready from unaffordable.
  - Built projects expose the current effect rather than the next effect.
  - Upgrade-ready appears only when the next tier is affordable.
  - Completed projects produce the final effect and Complete footer state.
  - Tier-path states correctly map current tiers 0 through 3.
- Expand the Homestead smoke flow to verify:
  - The overview, wallet, all three categories, and representative rows load.
  - A locked row remains tappable and exposes prerequisites.
  - Wheat Field opens through native push navigation.
  - The tab bar and back affordance remain present on detail.
  - Tier nodes and the persistent footer exist.
  - An affordable build/upgrade remains on detail and advances the UI.
- Manually inspect the supported portrait layout and primary visual states.
- Verify full-bleed crops, scroll-title handoff, wallet layout, tab/footer separation, and disabled-action legibility.
- After asset work, run `./Scripts/generate.sh --assets` and inspect only expected manifest, processed asset, and generated catalog changes.
- Run verification sequentially:
  1. `./Scripts/test-package.sh TrinketDesignSystem`
  2. Focused app/unit tests for Homestead presentation state
  3. `./Scripts/test.sh style`
  4. `./Scripts/check-ui-style.sh`
  5. `./Scripts/test.sh smoke SmokeHomesteadTests`
  6. `./Scripts/verify-changed.sh --dry-run`
  7. `./Scripts/verify-changed.sh`

## Assumptions and Defaults

- The attached mockup defines hierarchy and mood, not literal resource balances, category data, or bonus copy.
- The design is a native fantasy hybrid: warm art and gold/tinted accents with adaptive semantic surfaces and platform typography behavior.
- All nine live projects are visible from the start.
- Required amounts—not balance/required fractions—appear visually in the footer.
- Completed projects retain a stable Complete footer.
- The clean Homestead hero will eventually be supplied as a standalone source image; the implementation remains functional with its explicit fallback.
- Portrait remains the primary layout; accessibility adaptations beyond native SwiftUI defaults are not part of this product decision.
