# Player-facing writing and help

Use established game names from the
[product contract](../../../Docs/Product/Overview.md) and existing controls.
Follow [clarity through layout](../../../Docs/Product/DesignPrinciples.md#clarity-through-layout):
avoid taglines, helper text, subtitles that repeat titles, and instructions that
restate buttons. Keep real game rules, costs, consequences, and necessary
recovery information, and localize changed copy under the repository workflow.

- Name actions and destinations concretely (e.g. Build vs. Upgrade) and keep
  terminology consistent across the button, confirmation, and result.
- Trinket in-game description conventions: use separate lines without
  sentence-ending periods or semicolons, preserve lowercase continuation lines
  within a sentence, and omit minimum-amount qualifiers from effect descriptions
  while keeping actual minimums and activation requirements. Reset-progress and
  abandon-Voyage confirmations keep their existing prose.
- Keep fantasy flavor in narrative and rewards while keeping costs, eligibility,
  purchases, and recovery copy precise. Trim filler before shrinking text to fit,
  and match existing control capitalization.
- Show unavailability through actual requirements and visible state, pairing
  meaningful color differences with a symbol, shape, or native disabled state.
- In empty states, surface a real next action when one is available rather than
  filler copy.
- Follow the [failure and destructive-action contract](../../../Docs/AgentContext/swiftui-features.md)
  for recovery (keep technical failures internal, expose Retry/Back when
  blocked, and show inline consequences with Cancel + final action for
  destructive choices). [Automatic saving](../../../Docs/Product/Decisions.md)
  retries silently rather than prompting with save errors.

Teach non-obvious game actions in context—preferably through play—keeping any
help brief and dismissible. For simple contextual tips in scope, consider native
TipKit with eligibility that retires the tip once learned, preserving current
onboarding, monetization, and save/reset contracts.

Apple references: [Writing](https://developer.apple.com/design/human-interface-guidelines/writing),
[Offering help](https://developer.apple.com/design/human-interface-guidelines/offering-help),
[Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding).

Action/result terminology and empty-state guidance include modified adaptations
of Anthropic's design principles; see [source and license](foundations-and-process.md#adapted-source).
