# Accessibility policy

Trinket is a visual-heavy game and ships only basic accessibility semantics (PD-014). Keep the native behavior that costs nothing, make image semantics explicit, and avoid accommodation-specific product branches.

## What stays

- Whatever native SwiftUI provides for free: standard controls, `@ScaledMetric`, `minimumScaleFactor` where it prevents truncation for everyone.
- `accessibilityIdentifier` / `AccessibilityID` values. These are UI-test infrastructure, not accessibility; they are required on new player flows per `Docs/Platform/Testing.md`.
- Every `Image` explicitly uses a concise label when it carries meaning or `accessibilityHidden(true)` when adjacent text or its container already communicates the same meaning.

## What never gets added

- `accessibilityReduceMotion`, `accessibilityReduceTransparency`, `accessibilityDifferentiateWithoutColor`, or similar environment branches.
- Dynamic Type re-layout (`isAccessibilitySize` switches, type-size threading through presentation pipelines).
- Contrast accommodation or accessibility-setting UI tests beyond what native behavior gives away.

If Apple's platform forces a decision, take the simplest option and move on.

Existing Reduce Motion branches in `KeywordPlasmaBackground` and
`TrinketRarityLabel` are retained product behavior, not precedent for new
accommodation paths. Changing or removing them requires an explicit product task.
