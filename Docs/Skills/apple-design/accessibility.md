# Accessibility and reduced motion

Use this reference for reduced motion, reduced transparency, increased contrast, vestibular safety, and interaction choices that must work across abilities and contexts. Reduced motion does not mean no feedback; it means a gentler, non-vestibular equivalent.

## Independent user preferences

Respond to each signal independently and bake the behavior into components:

- **Reduced motion:** replace slides, springs, parallax, elastic effects, and overshoot with short opacity cross-fades or static transitions. Keep opacity and color changes that aid comprehension.
- **Reduced transparency:** make translucent surfaces frostier or solid by raising background opacity and dropping blur.
- **Increased contrast:** use stronger foreground/background separation and a
  defined border where material edges would otherwise disappear.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
@Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
```

Consume these values in shared DesignSystem and `TrinketMotion` components. Feature
views should select semantic variants rather than reimplement the same branches.

## Vestibular and visual safety

- Avoid full-viewport moving backgrounds and slow looping oscillations (around `0.2 Hz`, one cycle per five seconds).
- Avoid abrupt brightness jumps; ease dark↔light theme changes.
- Make large moving objects semi-transparent while they travel.
- Fade large surfaces out during a large reposition and back in after settling when that reduces visual strain.
- Preserve the same status, completion, warning, and error meaning when motion or material is removed.

## Interaction review

- Ensure controls have generous hit areas and cancellation paths, and do not depend on color, motion, sound, or haptics alone.
- Keep focus/wayfinding and the escape path clear when a panel or modal appears.
- Test larger text, increased contrast, reduced motion, reduced transparency, light/dark appearances, and real device input.

Apple references: [Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility/),
[`accessibilityReduceMotion`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion),
and [`accessibilityReduceTransparency`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency).
