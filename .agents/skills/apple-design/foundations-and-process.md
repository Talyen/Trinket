# Screen and flow critique

For a new flow or substantial redesign, establish the player's goal, the choices
needed to reach it, and the visible result. Review in Trinket's portrait-first
context with real game content.

Let fantasy artwork, content, and meaningful combat/reward feedback express
Trinket's identity. Prefer familiar native navigation and utility controls;
customize where it improves the game, preserving the battlefield, fanned hand,
and card identity. Apple's [brand guidance](https://developer.apple.com/videos/play/wwdc2026/251/)
supports distinctive content alongside familiar platform interactions.

- Can the player identify the primary action and its cost or consequence?
- Are related information and controls close enough to read as one decision?
- Can the player tell where they are and how to leave or cancel?
- Do labels use established game names and describe their destination or action?
- Do loading, empty, unavailable, success, and failure states explain what happens
  next when those states are reachable?
- Does each added visual element help a decision, establish hierarchy, or communicate
  an event? Remove elements whose only justification is decoration during a fix.

Use a working prototype when interaction is the uncertainty; a screenshot is
sufficient for an initial spacing or hierarchy comparison. Scale review to the
change rather than requiring a separate prototype phase for every edit.

Build interaction prototypes from the shipping SwiftUI components so their press,
disabled, and dismissal behavior is real. For a new or substantially changed flow,
an uncoached player attempt can expose hesitation or a wrong expectation and guide
the next refinement. Use it when player feedback is available; it is not a required
study or handoff gate. [Design with SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10115/).

Background: Apple's [Principles of great design](https://developer.apple.com/videos/play/wwdc2026/250/).
