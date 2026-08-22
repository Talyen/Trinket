# Accessibility policy

Trinket is a visual-heavy game and ships only bare-minimum accessibility (PD-007). Users who depend on accommodations will not have a good experience playing regardless, so accommodation code is pure complexity.

## What stays

- Whatever native SwiftUI provides for free: standard controls, `@ScaledMetric`, `minimumScaleFactor` where it prevents truncation for everyone.
- `accessibilityIdentifier` / `AccessibilityID` values. These are UI-test infrastructure, not accessibility; they are required on new player flows per `Docs/Platform/Testing.md`.

## What never gets added

- `accessibilityReduceMotion`, `accessibilityReduceTransparency`, `accessibilityDifferentiateWithoutColor`, or similar environment branches.
- Dynamic Type re-layout (`isAccessibilitySize` switches, type-size threading through presentation pipelines).
- Contrast, VoiceOver labeling, or accessibility-setting UI tests beyond what native behavior gives away.

If Apple's platform forces a decision, take the simplest option and move on.
