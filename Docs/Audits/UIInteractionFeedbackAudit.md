# UI Interaction & Feedback Audit

Goal: Find bugs that types miss — broken navigation, stuck states, missing tap feedback, accessibility gaps, and Apple HIG violations in a portrait-first SwiftUI game.

## Targets

- Manual pass through every product tab: Play, Collection (Heroes/Pets/Inventory), Homestead, Options, Search
- `rg -n 'sheet|popover|fullScreenCover|alert|confirmationDialog|menu|contextMenu' --type swift -g '!*Tests*'` — all overlay/modal boundaries
- `rg -n 'onTapGesture|onLongPressGesture|DragGesture|magnificationGesture' --type swift -g '!*Tests*'` — all gesture handlers
- `rg -n '.accessibilityIdentifier' --type swift` — UI test anchors; verify each is unique and descriptive

## Checks

### Navigation & modal hygiene

- `NavigationStack` within each tab; `TabView` is top-level only (`Docs/Design/AppleNativeGuidelines.md`)
- Every sheet, popover, and full-screen cover must have a clear dismiss path:
  - `toolbar` dismiss button or swipe-down for sheets
  - `Environment(\.dismiss)` for programmatic dismissal
  - Backdrop tap dismiss for popovers (or disable with `dismissBehavior: .interactive`)
- Confirm dialogs for destructive actions (delete save, reset progress, purchase restore) — with working cancel/backdrop dismiss
- No two overlayers (sheet + alert + modal) visible simultaneously unless explicitly designed
- `confirmationDialog` for multi-choice destructive actions; prefer `.cancel` button always present

### Gesture & interaction state

- One clear interaction mode at a time: scrolling, dragging, targeting, and modal should not fight
- Battle presentation: tap targets must be tappable — no gesture conflicts between unit selection, ability targeting, and scrolling the timeline
- `DragGesture` in Play map or Collection grid — ensure `.updating` state resets on cancel and drag end; no "stuck scroll" after gesture interruption
- Long-press context menus (if used on collection items) — verify they trigger on `.onLongPressGesture(minimumDuration:)` and do not interfere with tap navigation
- `TabView` selection changes must feel instant — no stutter when switching tabs

### Tap feedback

- Every interactive element (button, row, card, node) must give visible feedback on tap:
  - System buttons: `.buttonStyle(.borderedProminent)` or `.buttonStyle(.plain)` with highlight — handled by SwiftUI
  - Custom tappable views (map nodes, inventory cards, homestead slots): wrap in `Button` (preferred) or add `onTapGesture` with `withAnimation` feedback
  - Destructive actions: red tint + confirmation dialog before execution
- Loading/saving states: show `ProgressView` or skeleton — do not leave the UI frozen while `Task { … }` runs
- Battle victory/defeat: clear visual outcome with a dismiss path — no dead-end screens

### Overlays & popovers

- Hover tooltips (if present on iPad via cursor): must show/hide cleanly; must not block taps on underlying controls
- Homestead node tint presentation lives in `Trinket/Models/Homestead.swift` — verify tint changes are animated and readable at all Dynamic Type sizes
- No simulated glass or ad-hoc `.buttonStyle`, materials, or capsules without `// UIStyleCheck: allow - <reason>` (see `AGENTS.md`)
- Use `.controlSize`, `.buttonBorderShape`, `Label`, and semantic styles from `TrinketDesignSystem` first

### Accessibility (VoiceOver, Dynamic Type, Reduce Motion)

- Every interactive element must have an `accessibilityLabel` or `accessibilityIdentifier`
- `TabView` labels are derived from the tab item label text — verify they make sense in VoiceOver context
- Dynamic Type: text must reflow without truncation at all content size categories — test `.accessibilityTextContentType` where appropriate
- Reduce Motion: replace `withAnimation` with `.transaction { $0.animation = nil }` or use `UIView.animate` with `prefersReducedMotion` check; avoid parallax/scrolling background effects when Reduce Motion is on
- Contrast: semantic colors from `TrinketDesignSystem`; never hardcode hex values for text-on-background — use `primary`, `secondary`, `.background`, `.tertiaryBackground` etc.

### Portrait-first layout

- All screens must work in portrait orientation only (`project.yml` enforces this); verify no layout breaks on iPhone 16 Pro Max and iPhone SE (3rd gen)
- Thumb-reachable zones: primary actions in the lower half of the screen; navigation controls in the toolbar (top) or tab bar (bottom)
- Battle timeline (if scrollable) should not require a thumb stretch — consider vertical list layout
- `List` and `LazyVGrid` should respect safe areas; no content behind the tab bar or Dynamic Island

### Edge cases

- Rapid tapping: a button that triggers a `Task { … }` should disable or debounce to prevent duplicate work (e.g., stage start, forge craft, reward claim)
- Background/foreground: battle paused on `scenePhase` change; homestead timer should resume correctly
- Keyboard dismiss: search fields (Collection, Search tab) should dismiss keyboard on scroll or tap-away
- Empty states: Collection with no heroes, Inventory with no items, Homestead with no upgrades — each should show a helpful empty-state message, not a blank grid
