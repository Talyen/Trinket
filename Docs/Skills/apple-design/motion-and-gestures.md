# Motion and gestures

Use this reference for taps, drags, swipes, sheets, drawers, carousels, repositioning, springs, momentum, and any interaction that can be interrupted. Drawing chiefly on *Designing Fluid Interfaces* (WWDC 2018), the through-line is physical continuity: motion starts from the current on-screen value, follows the user’s velocity, projects where they are going, and can be grabbed and reversed at any instant.

## Response and direct manipulation

The moment lag appears, the feeling of directness falls off a cliff.

- Respond on touch-down, not only on release. Use a `ButtonStyle` or existing
  DesignSystem control style for immediate press feedback.
- Audit debounces, artificial timers, transition waits, and tap delays. Anything on the input path that is not essential is a regression.
- Keep feedback continuous during the interaction, not only at the end. A drag, slider, or drawer should update 1:1 with the input.
- Keep the dragged object glued to the finger and respect the offset from where it was grabbed; snapping to its center breaks the illusion.
- Use `@GestureState` for transient drag state so cancellation resets cleanly; use
  `DragGesture.Value.predictedEndTranslation` when the landing decision needs momentum.

Prefer `Button`, `DragGesture`, `GestureState`, `matchedGeometryEffect`, and the
existing `TrinketMotion` recipes over custom recognizers.

## Interruptibility

The thought and the gesture happen in parallel. Never lock out input during a transition.

- Animate from the **presentation** (live) value, never the logical target value. On interruption, read the current on-screen transform and start there; starting at the target causes a jump.
- Avoid fixed keyframe scripts for gesture-driven behavior. Use a spring that can
  retarget from the current value.
- When reversing, blend velocity instead of hard-cutting it. A spring that carries velocity through retargeting avoids a “brick wall” discontinuity (iOS additive animations do this natively).
- Decompose 2D motion into independent X and Y springs when their velocities can differ.

A closing modal that is grabbed again should follow the finger immediately rather than finish closing and then reopen.

## Springs and velocity handoff

Treat animation as a conversation between the user and the object, not a script. A spring lets new input change the target while motion stays continuous.

- **Damping ratio** controls overshoot: `1.0` is critically damped and smooth; values below `1.0` overshoot and oscillate.
- **Response** is how quickly the value reaches its target in seconds. It is not a fixed duration; settle time emerges from the spring.
- Start most UI at damping `1.0`. Use damping around `0.8` only when the gesture carried momentum (flick, throw, or drag release).

| Interaction | Damping | Response |
| --- | --- | --- |
| Move/reposition (for example, PiP) | `1.0` | `0.4` |
| Rotation | `0.8` | `0.4` |
| Drawer/sheet | `0.8` | `0.3` |

Prefer an existing `TrinketMotion` recipe. For a genuinely local interaction, use
SwiftUI `.spring(duration:bounce:)` with zero or low bounce by default; reserve
visible overshoot for a momentum-driven release.

When a gesture ends, preserve the release direction and projected endpoint. Do not
invent a hand-normalized velocity formula when SwiftUI already provides predicted
translation or the selected animation API handles retargeting.

## Momentum projection and snapping

Do not choose a snap point from release position alone. Use
`predictedEndTranslation` to select the nearest valid destination, then settle with
the established spring. Position, direction, and velocity should agree; a fast flick
may commit even when the finger has not crossed the midpoint.

## Spatial consistency and boundaries

- Enter and exit along the same path. A panel that enters from the right should dismiss to the right.
- Anchor menus, popovers, and sheets to the element that triggered them; their transform origin should preserve that relationship.
- Use the same spatial path and compatible spring behavior for reversible transitions.
- Let intermediate frames hint at the final state; motion should grow toward the destination rather than blindly interpolate. For example, Control Center modules grow up and out toward the finger.
- Rubber-band at bounds. Increase resistance progressively as the user drags farther past an edge instead of stopping hard.

## Gesture feel checklist

- **Tap:** highlight on down, commit on up, preserve at least the native 44-point
  target, and allow cancellation by dragging away.
- **Drag/swipe:** use the smallest threshold that resolves gesture competition, then
  track 1:1. Prefer the platform default before tuning a custom minimum distance.
- Detect plausible gestures in parallel from the first move; cancel losing recognizers once intent is clear. Final-state-only swipe events discard the continuous feedback needed for direct manipulation.
- Minimize disambiguation delays. Double-tap detection delays a single tap, so use it only where a double tap truly exists.

Apple reference: [Designing Fluid Interfaces](https://developer.apple.com/videos/play/wwdc2018/803/).
