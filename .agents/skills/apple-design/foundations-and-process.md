# Screen and flow critique

For a new flow or substantial redesign, write a short design intent before
implementation: the player's goal, the choices needed to reach it, the visible
result, and the real game content shown in Trinket's portrait-first context.
Identify the existing visual roles and layout hierarchy that support that goal,
and the artwork or meaningful game event that gives the screen its identity.
Reuse the design system's palette and typography rather than inventing a token
system for each screen.

Let fantasy artwork, content, and meaningful combat/reward feedback express
Trinket's identity. Prefer familiar native navigation and utility controls;
customize where it improves the game, preserving the battlefield, fanned hand,
and card identity. Apple's [brand guidance](https://developer.apple.com/videos/play/wwdc2026/251/)
supports distinctive content alongside familiar platform interactions.
The [artwork production guide](../../../Docs/Product/ArtworkStyleGuide.md#prompt-construction)
owns new artwork direction; a screen redesign does not imply replacing prepared
artwork or changing its budgets.

Review the intent against the request before building. If the arrangement could
be reused unchanged for an unrelated app, ground it in this player's actual
decision. Repeated equal-weight containers, decorative labels, or uniform
entrances can flatten information hierarchy; keep them when they communicate
real relationships or events. These are critique prompts, not bans on cards,
colors, capitalization, or particular type treatments. Follow the requested
visual direction and preserve established card identity.

Let the important content or event carry the emphasis. Use borders, labels,
spacing, and motion to explain grouping, priority, decisions, or changes;
remove decoration that competes with those jobs. Keep immediate input feedback
and scripted combat/reward spectacle. Restraint in utility screens is not a
reason to mute meaningful battle effects or sound.

- Can the player identify the primary action and its cost or consequence?
- Are related information and controls close enough to read as one decision?
- Can the player tell where they are and how to leave or cancel?
- Do labels use established game names and describe their destination or action?
- Do loading, empty, unavailable, success, and failure states explain what happens
  next when those states are reachable?

Use a working prototype when interaction is the uncertainty; a screenshot is
sufficient for an initial spacing or hierarchy comparison. Scale review to the
change rather than requiring a separate prototype phase for every edit. A local
spacing, price, or label correction does not need a new design intent or palette.
After implementation, compare the result with the intent and reachable states;
use available screenshots when appearance is uncertain and the routed UI
verification policy when new visual evidence is needed.

Build interaction prototypes from the shipping SwiftUI components so their press,
disabled, and dismissal behavior is real. For a new or substantially changed flow,
an uncoached player attempt can expose hesitation or a wrong expectation and guide
the next refinement. Use it when player feedback is available; it is not a required
study or handoff gate. [Design with SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10115/).

Background: Apple's [Principles of great design](https://developer.apple.com/videos/play/wwdc2026/250/).

## Adapted source

Design-intent, hierarchy, restraint, and critique guidance in this reference,
and the linked typography and writing references, was adapted for Trinket from
Anthropic's [frontend-design skill](https://github.com/anthropics/skills/blob/41bbe19d1a1a7eaab5e7bb9050a417e5c6cffc8f/skills/frontend-design/SKILL.md),
revision `41bbe19d1a1a7eaab5e7bb9050a417e5c6cffc8f` (September 3, 2026).
These are modified adaptations, not the upstream skill. The upstream material
is licensed under [Apache-2.0](LICENSE.txt). Web-specific implementation rules
and style prescriptions were omitted; Trinket's design system, native SwiftUI
interactions, artwork direction, and product policies remain authoritative.
