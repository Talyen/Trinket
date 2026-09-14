# Motion and gestures

Use native controls and existing `TrinketMotion` recipes before custom gesture
machinery. Keep press feedback immediate and motion tied to the player's input.

- Separate feedback from commitment: highlight on press, commit a button action
  on release, and allow cancellation by moving away. Preserve a usable hit target.
- Track a drag from its grab offset. Use `@GestureState` for transient state so
  cancellation resets it, without committing the game action in an update callback.
- Resolve competition with scrolling before tuning a custom drag threshold.
- For a momentum-based snap, use predicted translation to choose a valid endpoint.
  A position-based threshold is appropriate when the interaction requires deliberate
  placement; velocity should not silently change that rule.
- Prefer retargetable SwiftUI springs for interactive motion. Avoid custom sampling
  of presentation transforms or velocity formulas unless a demonstrated limitation
  requires them. Do not copy damping/response numbers from a different interaction.
- Keep reversible transitions spatially consistent. When changing interruption
  or reversal behavior, check the animation in flight as well as its endpoints.

Animation completion should not be the authority for a game-state mutation.
Preserve legitimate input guards while an action resolves; remove delays only when
they serve no state or interaction requirement. Scripted combat spectacle can use
sequenced motion even though direct manipulation needs interruption.

Check slow drags, quick releases, cancellation, interruption, repeated input,
and competing gestures when the change affects those behaviors or evidence
suggests a regression. Look for jumps, duplicate commits, or stranded state.
Unchanged interactions do not require revalidation merely because the screen
contains them.

Background: Apple's [Designing Fluid Interfaces](https://developer.apple.com/videos/play/wwdc2018/803/).
