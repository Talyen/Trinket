# Screen and flow critique

For a new flow or substantial redesign, anchor on the player's goal, the choices
needed to reach it, the visible result, and real game content in Trinket's
portrait-first layout. Build on existing visual roles, palette, and typography
from the design system, and let fantasy artwork and meaningful combat or reward
feedback carry Trinket's identity alongside familiar native navigation and
utility controls (preserving the battlefield, fanned hand, and card identity).
Apple's [brand guidance](https://developer.apple.com/videos/play/wwdc2026/251/)
supports distinctive content paired with familiar platform interactions.
New artwork direction belongs to the
[artwork production guide](../../../Docs/Product/ArtworkStyleGuide.md#prompt-construction).

Let the important content or event carry the emphasis. Use borders, labels,
spacing, and motion to clarify grouping, priority, decisions, and state changes,
and trim decoration that competes with them. Keep immediate input feedback and
scripted combat or reward spectacle—restraint in utility screens shouldn't mute
meaningful battle effects or sound.

Useful critique questions:

- Can the player immediately identify the primary action and its cost or consequence?
- Are related details and controls grouped so they read as one decision?
- Does the screen make sense without taglines, helper text, or secondary labels?
  If not, [fix the layout](../../../Docs/Product/DesignPrinciples.md#clarity-through-layout).
- Is it obvious where the player is and how to leave or cancel?
- Do labels use established game names and clearly describe their destination or action?
- Do reachable loading, empty, unavailable, success, and failure states show what happens next?

## References and alternatives

When tackling a substantial redesign, check the user's visual references and
relevant Trinket screens for helpful cues like artwork scale and crop, focal
point, text density, spacing, contrast, and material treatment.

If the visual direction is still open, offering two meaningfully distinct
portrait compositions with real game content (varying hierarchy, density, or
artwork placement rather than just recoloring) is a quick way to get a clear
preference. When the user approves or rejects a visual direction that will
inform future work, consider linking the reference beside the owning feature
documentation.

## Render and critique

When using [visual inspection](../../../Docs/Platform/Verification.md#visual-inspection),
look closely at the rendered screen for concrete issues—focal priority, artwork
crops, readable costs and consequences, control grouping, long names, and
empty or unavailable states at normal phone size. For a new flow, check entry,
primary action, exit, and real press/disabled/dismissal behavior using shipping
SwiftUI components.

Background: Apple's [Principles of great design](https://developer.apple.com/videos/play/wwdc2026/250/)
and [Design with SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10115/).

## Adapted source

Design-intent, hierarchy, restraint, and critique guidance in this reference,
and the linked typography and writing references, was adapted for Trinket from
Anthropic's [frontend-design skill](https://github.com/anthropics/skills/blob/41bbe19d1a1a7eaab5e7bb9050a417e5c6cffc8f/skills/frontend-design/SKILL.md),
revision `41bbe19d1a1a7eaab5e7bb9050a417e5c6cffc8f` (September 3, 2026).
These are modified adaptations, not the upstream skill. The upstream material
is licensed under [Apache-2.0](LICENSE.txt). Web-specific implementation rules
and style prescriptions were omitted; Trinket's design system, native SwiftUI
interactions, artwork direction, and product policies remain authoritative.
