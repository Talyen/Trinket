# Player-facing writing and help

Use when changing labels, unavailable/error states, or teaching a game interaction.
Use established names from the owning [product contract](../../../Docs/Product/Overview.md)
and actual controls; do not create a second glossary or rename game concepts as
incidental copy work.

Follow [clarity through layout](../../../Docs/Product/DesignPrinciples.md#clarity-through-layout):
avoid taglines, helper text, and secondary labels. If a screen needs them to make
sense, fix the layout instead. Use clearer grouping, placement, selection/disabled
state, or an action label. Remove subtitles that repeat titles,
instructions that restate buttons, decorative category labels, and success copy
for already-visible outcomes. Keep actual game rules, costs, consequences, and
necessary recovery information. “Upgrade” beside its cost and benefit does not
need “Upgrade your building to increase production.” Do not shrink text to retain
redundant copy. Localize retained or changed copy under the repository workflow.

- Name the action or destination concretely. Build and Upgrade describe distinct
  Homestead actions; vague labels such as Continue need an obvious next step.
  Keep the action's terminology consistent in its confirmation and visible
  result; do not describe a different operation after the player commits.
- In-game descriptions use separate lines without sentence-ending periods or
  semicolons. Preserve lowercase continuation lines within a sentence. Omit
  minimum-amount qualifiers from effect descriptions while retaining gameplay
  minimums and activation requirements. Reset-progress and abandon-Voyage
  confirmation explanations keep their existing prose.
- Keep fantasy character in narrative and rewards while making costs, eligibility,
  purchases, and recovery instructions precise. Remove filler and repetition before
  shrinking text to fit. Match existing capitalization for the kind of control.
- Make an unavailable action's eligibility clear at the choice through its actual
  requirements and visible state. Pair essential color differences with a symbol,
  shape, or native disabled state.
- When an empty state leaves the next step unclear, make an actual available
  action prominent and place it where the player needs it. Do not invent an action
  or add a tutorial just to fill the space.
- Follow the [failure and destructive-action contract](../../../Docs/AgentContext/swiftui-features.md)
  for recovery: keep technical failures internal, expose Retry/Back when blocked,
  and use inline consequences with Cancel and a final action for destructive choices.
  Availability and consequence copy remains concrete; pending or rejected actions
  must not look successful. [Automatic saving](../../../Docs/Product/Decisions.md)
  retains silent retries rather than save-error prompts.

Teach non-obvious game actions in their context, preferably through play. Keep help
brief and dismissible; don't explain familiar iOS controls or require memorizing a
tutorial before playing. A new help system needs evidence of a discovery problem.
When a simple contextual tip is in scope, consider native TipKit, with eligibility that stops
showing it after the player learns the action. Multi-step instruction needs a
playable explanation rather than an oversized tip. Preserve current onboarding,
monetization, and save/reset contracts when deciding tip persistence.

Inspect copy with actual long names, costs, and the unavailable state. For a changed
flow, check that the label predicts the result and that help can be dismissed without
blocking the action. No new telemetry or player-facing tutorial is implied by this
reference.

Apple references: [Writing](https://developer.apple.com/design/human-interface-guidelines/writing),
[Offering help](https://developer.apple.com/design/human-interface-guidelines/offering-help),
[Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding).

Action/result terminology and empty-state guidance include modified adaptations
of Anthropic's design principles; see [source and license](foundations-and-process.md#adapted-source).
