# Performance and feedback

Use this reference for frame smoothness, animation workload, visual/audio/haptic feedback, and review of perceived responsiveness. Smoothness is about what is in the frames, not only the reported frame rate.

## Frame-level smoothness

- Keep per-frame positional change below the perception threshold to avoid strobing.
- For very fast motion, a subtle motion blur or stretch can encode speed better than a hard, sharp streak.
- Prefer transform and opacity animation when they preserve the design; in SwiftUI,
  avoid state changes that invalidate unrelated layout.
- Prewarm expensive motion work only where motion is imminent; keep stable SwiftUI
  identity and scope observable state to the surface that renders it.
- Check the actual device and screen, not only a simulator or a static screenshot.

## Multimodal feedback

Visual, sound, and haptic feedback should form one causal event. Use these three rules from *Designing Audio-Haptic Experiences*:

1. **Causality:** make it obvious what caused the feedback. Trigger it on the actual event (the toggle flipping or item snapping home), and match its character to the action’s physicality.
2. **Harmony:** derive visual, sound, and haptic feedback from the same committed
   event and schedule them together. Avoid independent timers that drift.
3. **Utility:** add feedback only where it earns its place. Reserve sound and haptics for meaningful moments such as success, error, commit, and snap; over-feedback trains people to ignore it.

For Trinket, route sound and haptics through the app’s existing audio and
feedback systems rather than ad-hoc effect calls.

## Perceived-performance review

- Is press feedback immediate, with no avoidable debounce or timer?
- Does the interaction remain responsive while a background operation runs?
- Can a user interrupt or cancel expensive motion without waiting for a transition to finish? See [Motion and gestures](motion-and-gestures.md).

Apple references: [Understanding hitches](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app)
and [Designing Audio-Haptic Experiences](https://developer.apple.com/videos/play/wwdc2019/810/).
