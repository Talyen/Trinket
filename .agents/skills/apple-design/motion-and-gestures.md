# Motion and gestures

Prefer native controls and existing `TrinketMotion` recipes before building
custom gesture machinery. Keep press feedback immediate and motion tied to the
player's input.

Aim for Apple's 44×44 pt touch target and clear separation between adjacent
actions; check the effective hit region (native padding, `contentShape`) before
adding frames. Consider thumb reach for frequent actions while preserving the
established battlefield, card tap/inspection paths, and system edge gestures.
Essential custom gestures should have a discoverable alternative.

- Separate feedback from commitment: highlight on press, commit button actions
  on release, and allow cancellation by moving away.
- Track drags from the grab offset. Use `@GestureState` for transient drag state
  so cancellation resets cleanly, and avoid committing game actions inside update
  callbacks.
- Resolve scroll-view competition before tuning custom drag thresholds.
- For momentum-based snaps, use predicted translation to choose a valid endpoint;
  for deliberate placement, a position-based threshold is usually clearer.
- Prefer retargetable SwiftUI springs for interactive motion, tuned to the
  specific interaction, rather than custom transform/velocity sampling unless
  needed.
- Keep reversible transitions spatially consistent, including when interrupted
  mid-flight.

Avoid making animation completion the authority for a game-state mutation.
Preserve legitimate input guards while an action resolves; scripted combat
spectacle can use sequenced motion even when direct manipulation stays
interruptible.

When changing gesture or motion behavior, watch for jumps, duplicate commits, or
stranded state across slow drags, quick releases, cancellation, interruption,
repeated input, and competing gestures.

Background: Apple's [Designing Fluid Interfaces](https://developer.apple.com/videos/play/wwdc2018/803/).
Touch guidance: [Designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games)
and [Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures).
