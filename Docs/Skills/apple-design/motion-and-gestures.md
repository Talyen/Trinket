# Motion and gestures

Use this reference for taps, drags, swipes, sheets, drawers, carousels, repositioning, springs, momentum, and any interaction that can be interrupted. Drawing chiefly on *Designing Fluid Interfaces* (WWDC 2018), the through-line is physical continuity: motion starts from the current on-screen value, follows the user’s velocity, projects where they are going, and can be grabbed and reversed at any instant.

## Response and direct manipulation

The moment lag appears, the feeling of directness falls off a cliff.

- Respond on pointer-down/touch-down, not release. Highlight a button the instant it is pressed.
- Audit debounces, artificial timers, transition waits, and tap delays. Anything on the input path that is not essential is a regression.
- Keep feedback continuous during the interaction, not only at the end. A drag, slider, or drawer should update 1:1 with the input.
- Keep the dragged object glued to the finger and respect the offset from where it was grabbed; snapping to its center breaks the illusion.
- On platforms with pointer events, capture the pointer so tracking continues outside the element. Track a short position/timestamp history to calculate release velocity.

```css
/* Feedback lives on the press, and it is instant. */
.button:active {
  transform: scale(0.97);
  transition: transform 100ms ease-out;
}
```

```js
el.addEventListener('pointerdown', (e) => {
  el.setPointerCapture(e.pointerId);
  const grabOffset = e.clientY - el.getBoundingClientRect().top;
  // Track position + timestamp history for velocity.
});
```

In SwiftUI, use the equivalent gesture state and first-party gesture APIs while preserving the same direct-tracking and cancellation behavior.

## Interruptibility

The thought and the gesture happen in parallel. Never lock out input during a transition.

- Animate from the **presentation** (live) value, never the logical target value. On interruption, read the current on-screen transform and start there; starting at the target causes a jump.
- Avoid fixed CSS transitions and keyframes for gesture-driven behavior. Use a spring or equivalent that retargets from the current value.
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

When using a web spring library, Motion/Framer Motion’s `bounce` + `duration` API maps approximately to damping + response. A safe house style is `bounce: 0` by default; reserve bounce for momentum-driven interactions:

```js
import { animate } from 'motion';

animate(el, { y: 0 }, { type: 'spring', bounce: 0, duration: 0.4 });
animate(el, { y: target }, { type: 'spring', bounce: 0.2, duration: 0.4 });
```

When a gesture ends, continue at the finger’s exact release velocity. Some spring APIs want relative velocity:

```
relativeVelocity = gestureVelocity / (targetValue - currentValue)
```

For example, at `y=50` heading to `y=150`, a `50px/s` release is `0.5` normalized velocity. APIs that accept absolute velocity should receive the raw value.

## Momentum projection and snapping

Do not choose a snap point from the release position alone. Project the resting position from release velocity, then choose the nearest snap point to that projection. Apple’s exponential-decay form is:

```js
// decelerationRate ≈ 0.998 for normal scroll feel; 0.99 for snappier motion
function project(initialVelocity, decelerationRate = 0.998) {
  return (initialVelocity / 1000) * decelerationRate / (1 - decelerationRate);
}

const projectedEndpoint = currentPosition + project(releaseVelocity);
const target = nearestSnapPoint(projectedEndpoint);
animateSpringTo(target, { velocity: releaseVelocity });
```

Do not substitute the textbook `v²/(2·decel)` formula. Use the exponential-decay form used by good sheets and carousels. At release, decide whether to reverse or commit from the **velocity sign**, not position alone.

## Spatial consistency and boundaries

- Enter and exit along the same path. A panel that enters from the right should dismiss to the right.
- Anchor menus, popovers, and sheets to the element that triggered them; their transform origin should preserve that relationship.
- Mirror easing on reversible transitions so outbound and return paths agree (inverse cubic-bezier control points when appropriate).
- Let intermediate frames hint at the final state; motion should grow toward the destination rather than blindly interpolate. For example, Control Center modules grow up and out toward the finger.
- Rubber-band at bounds. Increase resistance progressively as the user drags farther past an edge instead of stopping hard.

```js
function rubberband(overshoot, dimension, constant = 0.55) {
  return (overshoot * dimension * constant) /
    (dimension + constant * Math.abs(overshoot));
}
```

## Gesture feel checklist

- **Tap:** highlight on down, commit on up; provide about `10px` of hit padding/hysteresis and allow cancel by dragging away and back.
- **Drag/swipe:** require a small movement threshold (about `10px`) before committing to a direction, then track 1:1.
- Detect plausible gestures in parallel from the first move; cancel losing recognizers once intent is clear. Final-state-only swipe events discard the continuous feedback needed for direct manipulation.
- Minimize disambiguation delays. Double-tap detection delays a single tap, so use it only where a double tap truly exists.

## Motion quick reference

| Need | Technique | Concrete value |
| --- | --- | --- |
| Default UI spring | Critically damped, no overshoot | damping `1.0`, response `0.3–0.4` |
| Momentum/flick spring | Slightly under-damped | damping `~0.8`, response `0.3–0.4` |
| Gesture → spring | Hand off release velocity | `gestureVelocity / (target − current)` if normalized |
| Flick landing point | Project momentum | `current + (v/1000)·d/(1−d)`, `d ≈ 0.998` |
| Interrupt cleanly | Start from live presentation value | read the on-screen transform |
| Avoid reversal brick wall | Carry velocity through retargeting | velocity-aware spring |
| Reversible transition | Mirror easing | inverse curve |
| Decide reverse/commit | Use velocity sign | at release |
| 1:1 drag | Capture input and preserve grab offset | continuous updates |
| Feedback | Down + continuous | never only at end |
| Boundary | Rubber-band | progressive resistance |
