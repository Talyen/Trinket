# Design principles

Standing policy for all player-facing UI/UX design and gameplay interactions.
[Product decisions](Decisions.md) records the approved direction; this document
owns the principle, rationale, and review criteria.

## Every player action is perceptible

**Every supported player action must produce a prompt, perceptible visual and/or
audible response that communicates what the game registered and what happened.**

This principle (PD-032) covers taps, clicks, supported keyboard/controller input,
selection, navigation, dragging, card play, cancellation, and attempted actions
on interactive surfaces. Existing responses count: a native pressed state,
changed selection, card following the finger, screen transition, or visible
gameplay result can satisfy it. Extra animation or sound is unnecessary when
the existing response communicates the action clearly. This policy does not
require adding new input methods.

### Apply the principle

- Acknowledge input promptly. When completion takes time, show pending work and
  distinguish it from the eventual outcome. A press response acknowledges input;
  success feedback requires a successfully committed action.
- Keep feedback truthful and tied to the event it represents. Coordinate visual,
  sound, and haptic outcome feedback with the same resolved event so repetition
  or interruption cannot produce duplicate or misleading success cues.
- Make unavailable actions visibly unavailable before interaction. If an
  interactive action is rejected or cancelled, resolve it perceptibly without
  implying success. Preserve the existing [failure presentation
  contract](../AgentContext/swiftui-features.md): no error/operation-status text
  or authored alerts; use visible eligibility, inline state, unlabeled progress
  during active work, and Retry/Back controls when blocked.
- Keep essential outcomes understandable with sound and haptics off. Sound and
  haptics can reinforce visual feedback; haptics alone do not satisfy the
  principle. Preserve Options settings and native accessibility semantics under
  [PD-014](Decisions.md); this principle adds no bespoke accessibility modes.
- Scale intensity to importance. Reuse native responses and avoid fatiguing
  repetition. Continuous gestures need continuous feedback, not a separate
  effect for every input sample. Taps on noninteractive background space and
  unsupported input do not require invented reactions.
- Feedback must not delay gameplay or introduce animation locks. Preserve
  [continuous card play](CardPlay.md), including visual-only finishing taps;
  their card departure acknowledges the tap without implying another combat
  result or changing rewards.

### Trinket examples

These are design examples, not evidence that every existing surface complies.

| Player action | Appropriate response |
|---|---|
| Open Collection or inspect a card | Native press feedback and the destination/details appearing |
| Select a hero or change a loadout | Visible selection or equipped state changes |
| Drag a card, then cancel | The card follows the finger and returns without spending Mana or playing success feedback |
| Play a valid card | Prompt card departure and the actual cost, target, and resolved combat result remain legible |
| Encounter an unavailable action | Visible disabled/eligibility state; an interactive rejection settles without a success cue |
| Start an action that takes time | Prompt acknowledgment, active progress, then a distinct completed or blocked state |
| Play with sound and haptics off | Selection, resource changes, combat results, and action outcomes remain visually understandable |

### Why feedback matters

- **Clarity and recovery.** Apple's guidance explains that feedback helps people
  understand what is happening, what they can do next, and the results of their
  actions while avoiding mistakes. In Trinket, feedback should let the player
  distinguish a registered press from a completed action.
  [Apple HIG: Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback).
- **Confidence and control.** Nielsen Norman Group describes timely feedback as
  reducing uncertainty and repeated taps, while visible system state helps people
  make decisions and trust the interface. A player should not need to repeat a
  card tap or reward claim just to discover whether it registered.
  [Visibility of System Status](https://www.nngroup.com/articles/visibility-system-status/).
- **Gameplay understanding and fairness.** Riot identifies clear visual feedback
  as necessary for understandable, fair-feeling combat outcomes in VALORANT.
  Applied to Trinket, this supports making card costs, targets, damage, and rewards
  perceptible so players can connect choices with consequences. This is a design
  application of Riot's rationale, not a measured claim about Trinket.
  [Peeking into VALORANT's Netcode](https://www.riotgames.com/en/news/peeking-valorants-netcode).
- **Perceivability.** Microsoft's game accessibility guidance explains that
  multiple sensory channels help players perceive important game information,
  and that haptics need another cue because they may be disabled or unavailable.
  This supports reinforcing meaningful feedback while keeping essential outcomes
  visually understandable within Trinket's existing accessibility scope.
  [Xbox Accessibility Guideline 103](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103).

### Review checklist

When designing or changing an interaction, check:

- Can the player perceive that input registered and understand its outcome?
- If completion is delayed, are acknowledgment, pending work, and outcome distinct?
- Do unavailable, rejected, cancelled, and repeated actions remain truthful and
  avoid false or duplicate success feedback?
- Does the interaction remain understandable with sound and haptics off?
- Is feedback proportional, coherent during interruption, and free of new input locks?

Use the existing [design feedback guidance](../../.agents/skills/apple-design/performance-and-feedback.md)
for implementation mechanics and [verification policy](../Platform/Verification.md#choosing-ui-verification)
to choose evidence appropriate to the change. This principle is standing guidance,
not a claim of complete existing coverage or a requirement for a broad audit,
new automated tests, or simulator execution on every change.
