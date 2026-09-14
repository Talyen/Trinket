# Player-facing writing and help

Use when changing labels, unavailable/error states, or teaching a game interaction.
Use established names from the owning [product contract](../../../Docs/Product/Overview.md)
and actual controls; do not create a second glossary or rename game concepts as
incidental copy work.

- Name the action or destination concretely. Build and Upgrade describe distinct
  Homestead actions; vague labels such as Continue need an obvious next step.
- Keep fantasy character in narrative and rewards while making costs, eligibility,
  purchases, and recovery instructions precise. Remove filler and repetition before
  shrinking text to fit. Match existing capitalization for the kind of control.
- Explain an unavailable action near the choice when its reason is unclear. Pair
  essential color differences with a label, symbol, shape, or native disabled state.
- For reachable errors, state what happened and the next useful action without
  blame or implementation jargon. Use an alert only when interruption is warranted;
  [automatic saving and destructive-action decisions](../../../Docs/Product/Decisions.md)
  take precedence over generic error or confirmation advice.

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
