# Performance and feedback

Use this reference for frame smoothness, animation workload, visual/audio/haptic feedback, and review of perceived responsiveness. Smoothness is about what is in the frames, not only the reported frame rate.

## Frame-level smoothness

- Keep per-frame positional change below the perception threshold to avoid strobing.
- For very fast motion, a subtle motion blur or stretch can encode speed better than a hard, sharp streak.
- Animate compositor-friendly properties such as transform and opacity. On the web, `requestAnimationFrame` is the display-synced clock (Apple uses `CADisplayLink`); in SwiftUI use the equivalent platform animation APIs and avoid work that invalidates unrelated layout.
- Hint or prewarm expensive motion work only where motion is imminent (`will-change` on the web; stable SwiftUI view identity and scoped state in the app).
- Check the actual device and screen, not only a simulator or a static screenshot.

## Multimodal feedback

Visual, sound, and haptic feedback should form one causal event. Use these three rules from *Designing Audio-Haptic Experiences*:

1. **Causality:** make it obvious what caused the feedback. Trigger it on the actual event (the toggle flipping or item snapping home), and match its character to the action’s physicality.
2. **Harmony:** fire visual, sound, and haptic feedback on the same frame. Latency between them destroys the illusion; do not let a CSS transition or other animation lag the audio or haptic (for example, a web Vibration API call).
3. **Utility:** add feedback only where it earns its place. Reserve sound and haptics for meaningful moments such as success, error, commit, and snap; over-feedback trains people to ignore it.

For Trinket, route sound and haptics through the app’s existing audio and feedback systems. Do not add ad-hoc effects or product colors to a feature view.

## Perceived-performance review

- Is press feedback immediate, with no avoidable debounce or timer?
- Does the interaction remain responsive while a background operation runs?
- Do reduced-motion users receive an equally clear status and completion signal? See [Accessibility](accessibility.md).
- Can a user interrupt or cancel expensive motion without waiting for a transition to finish? See [Motion and gestures](motion-and-gestures.md).
