# SwiftUI feature context

Use for tabs, screens, navigation, shared views, design-system polish, and accessibility identifiers.

## Ownership

Screens live in `Trinket/Features/`; shared views and feature support live in
`TrinketFeatureSupport`; app and Play orchestration live in `TrinketAppState`.
Packages never import the app. Feature views own transient UI state, not session stores.

Read the relevant implementation contract below for the behavior being changed.

## Interaction constraints

Player-facing failures use no error or operation-status text and no authored native
alerts or confirmation dialogs except the reset confirmation below. Keep diagnostics
internal, action eligibility visible before a tap, and rejected/pending outcomes
distinct from success. Use
unlabeled progress only during active work, with Retry/Back controls when blocked.
Destructive actions expand inline consequences with Cancel and a final action;
revalidate on that final action. Reset Game Progress uses a native alert with
concise consequences, Cancel, and a destructive Reset Progress action.
Full Game purchasing is a narrow exception: show
concise inline pricing, pending-approval, verification, and restoration outcomes
under [Purchases](../Platform/Purchases.md). Keep cancellation quiet and avoid
additional alerts over Apple's purchase authorization.

Artwork stays pinned/prewarmed on first presentation under the
[pin lifecycle](ui-performance.md#first-paint-pins-and-encounter-transitions).
Use native SwiftUI sheets. For layout, copy, artwork or motion changes,
inspect the shipping UI under the [visual completion gate](../Platform/Verification.md#visual-completion-gate).

## Implementation contracts

The app root keeps `appearsActive` true so switching apps does not grey out game
controls. Keep actual action eligibility in `isEnabled`/`.disabled` and continue
using the real `scenePhase` for lifecycle work and decorative motion.

The app root uses `trinketSoftTopScrollEdge` for the native soft top effect on
iOS 26+; iOS 18 retains its native scroll/navigation appearance. Detail headers
hide the newer effect until their title is pinned. Keep availability checks in
shared chrome, preserving readable controls on both appearances.

Use [swiftui-specialist](../../.agents/skills/swiftui-specialist/SKILL.md) for
SwiftUI implementation correctness and update performance, and
[swiftui-whats-new-27](../../.agents/skills/swiftui-whats-new-27/SKILL.md) for SDK 27
migration or new APIs. Each routes to topic-specific Apple references; load only
the relevant topic. [apple-design](../../.agents/skills/apple-design/SKILL.md)
owns player-facing design procedure.

For UI/UX and gameplay interaction changes, apply [Design principles](../Product/DesignPrinciples.md)
(PD-032): every supported player action needs prompt, perceptible feedback;
existing visible responses count. The product owner supplies outcome and review rules.

Preserve first-screen artwork pins, launch prewarming, and mounted tab/battle
surfaces. When changing artwork loading, launch covers, tab mounting, or first-frame
performance, read [UI performance](ui-performance.md) before editing.

Item-label shine derives from the current immutable item's displayed affixes.
Colors remain semantic values; resolve them in the rendering environment.
Item-detail hero sizing uses the presentation container before navigation chrome
and the action footer reserve space. Keep its outer measurement extended through
the top safe area so inspection roots and pushed details share the artwork height.
Apply that footer's safe-area inset directly to the scroll view so final traits
remain reachable above the fixed action.

Sheets use standard native SwiftUI motion throughout the app. Do not
attach source-linked zoom transitions to sheets; interactive zoom dismissal can
visibly jump on physical devices. Preserve the existing detents, native drag to
dismiss, artwork preparation, and dismissal cleanup. Navigation-stack pushes keep
their existing transitions.

Use current SwiftUI per [Current vs banned SwiftUI](../Platform/ApplePlatformReference.md#current-vs-banned-swiftui).
Apply the shared [content beside native bars](../Platform/ApplePlatformReference.md#content-beside-native-bars)
policy to all screens, including grids, shelves, action docks and custom gameplay input.
Do not reintroduce the banned column. Keep the root tab bar fully expanded. Hidden toolbar chrome on Battle and detail-hero screens is an intentional art-forward choice.

Prefer the narrowest environment owner for a subtree (`BattleSession`, encounter sessions) over whole `AppState` when the view only needs that slice. Use shared controls, chrome, colors, glass and typography from [TrinketDesignSystem](../../Packages/TrinketDesignSystem/README.md). Feature views must not call raw `.glassEffect` / `.buttonStyle(.glass*)` or invent one-off colors. Use `TrinketMotion` for reusable fluid motion. File-level `@ViewBuilder` helpers that touch DesignSystem modifiers must be `@MainActor` (or methods on a `View`).

For Play/Battle observation or shell routing, use
[runtime ownership](battle-runtime.md#ownership) and
[observation boundaries](battle-runtime.md#play-observation-boundaries).

New player flows need a stable `AccessibilityID` from `TrinketFeatureSupport` (or an
existing appropriate one). Add or retire UI coverage per the [keep/drop rubric](../Platform/Testing.md#ui-keep-drop-rubric);
a view change alone does not require a test. IDs are selectors, not substitutes for
player-facing semantics: preserve native labels and add a concise label/value when a
custom control is ambiguous. Accessibility follows [PD-014](../Product/Decisions.md):
preserve native text scaling and existing shared motion/contrast accommodations;
do not add bespoke accessibility modes or setting-specific layout branches.
`TrinketUITests/README.md` owns launch args, screen helpers, and speed rules.
PD-014 allows bounded critical-control settings tests without establishing complete
VoiceOver gameplay or changing the visual-first product scope.

Use `trinketPresentationVisibility` for retained and reveal content: semantic
visibility owns opacity, hit testing, and accessibility exposure together, without
unmounting prewarmed surfaces. Supply an explicit opacity only when a separate
visual transition must remain visible without interaction (for example, a defeated
combatant). Visible unavailable controls remain discoverable and disabled.
Entrance sequencing advances visibility when each reveal starts; an animation's
delay must not expose invisible controls early. Keep inspection availability
separate from primary actions through `InspectableTapButton` and the existing
encounter presentation contract. Cache readiness controls artwork presentation,
not gameplay eligibility. Party shelves and grids share their selection eligibility
rule, and card tap, drag, and accessibility activation share one play-intent gate.
Shop and Mystery commands require the session captured by their cover; the encounter
owner checks reference identity and save generation before actions, retries, and
completion callbacks. Retiring covers cannot buy, resolve, or dismiss a replacement.
Party pickers capture selected-first ordering once per presentation and share it
between shelves and grids. Selection changes animate emphasis without reordering
the choices; reopening captures the new selection order. Eligibility stays live.
