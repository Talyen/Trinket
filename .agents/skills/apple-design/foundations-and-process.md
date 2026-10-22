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

## References and alternatives

Before a substantial redesign, inspect the user's visual references and relevant
previously approved Trinket screens. Name the useful properties: artwork scale and
crop, focal point, text density, spacing, contrast, and material treatment. Do not
assume an existing screen is approved merely because it ships.

When the direction is unresolved, render two compositions with real game content
at the intended portrait size. Vary hierarchy, density, or artwork placement;
recoloring the same layout is not an alternative. Show a simple A/B comparison
for the user's preference, without a persuasive design essay. An already selected
direction or a localized correction does not require another choice.

Retain explicit approvals and rejections as visual references beside the owning
feature documentation: link durable images and record the specific accepted or
rejected property. Obtain an explicit preference before calling a reference
user-approved. Keep only examples that change future decisions; do not create an
empty gallery or preserve every intermediate render. Approved references guide
composition, not permission to copy unrelated features.

## Render, critique, refine

Follow the [visual completion gate](../../../Docs/Platform/Verification.md#visual-completion-gate).
Review the render before rereading the implementation rationale. State concrete
visible defects, such as “the wallet competes with the purchase choice,” and fix
them; numerical self-scores and “looks polished” are not evidence.

Inspect composition and game identity as well as correctness: one clear focal
priority, deliberate artwork crops, readable costs and consequences, related
controls grouped together, and no redundant explanations or competing decoration.
Check long names and relevant unavailable/empty states at normal phone size.
A new flow also needs inspection of its entry, primary action, and exit; verify
motion and gesture behavior through interaction or recording. Use shipping
SwiftUI components so press, disabled, and dismissal behavior is real.

For substantial redesigns, make a separate critique pass against the references
and brief before reading the implementer's explanation. An independent reviewer
is useful when available, but does not replace rendered evidence or require
routine delegation. Uncoached player feedback can expose hesitation when
available; it is not a required study. [Design with SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10115/).

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
