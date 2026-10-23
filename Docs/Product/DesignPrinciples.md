# Design principles

Standing policy for player-facing UI/UX and gameplay interactions.
[Product decisions](Decisions.md) records the approved direction.

## Every player action is perceptible

**Every supported player action must produce a prompt, perceptible visual and/or
audible response that communicates what the game registered and what happened.**

PD-032 covers supported input, selection, navigation, dragging, card play,
cancellation, and interactive attempts. Existing responses count: a native press
state, changed selection, card following the finger, navigation, or visible game
result. Extra animation or sound is unnecessary when that response is clear;
this rule adds no input methods.

### Apply the principle

- Acknowledge input promptly. Show pending work when completion takes time;
  distinguish acknowledgment from a successfully committed outcome.
- Tie visual, sound, and haptic outcomes to the same resolved event. Repetition,
  cancellation, and interruption must not duplicate or invent success.
- Keep essential outcomes understandable with sound and haptics off. Preserve
  Options preferences and [PD-014](Decisions.md) accessibility semantics; haptics
  alone are insufficient and no bespoke accessibility modes are added.
- Scale intensity to importance. Continuous gestures need continuous feedback;
  background taps and unsupported input need none. Preserve
  [continuous card play](CardPlay.md), including visual-only finishing taps,
  without delaying gameplay or adding animation locks.

### Trinket examples

| Action | Appropriate response |
|---|---|
| Open Collection or change a loadout | Native press/navigation or visible equipped state |
| Drag and cancel a card | Follow the finger, then return without spending Mana or signaling success |
| Play a card | Prompt departure with legible costs and resolved results; a finishing tap only departs |

These examples guide design; they do not certify current coverage.

## Failure presentation

Make unavailable actions visibly unavailable before interaction. Rejected or
cancelled interactive actions settle perceptibly without implying success.
Keep diagnostics internal: no error or operation-status text and no authored
alerts or confirmation dialogs except Reset Game Progress. Use visible eligibility,
inline state, unlabeled progress during active work, and Retry/Back when blocked.

Destructive actions expand inline consequences with Cancel and a final action;
revalidate on that final action. Reset Game Progress uses a native alert with
concise consequences, Cancel, and a destructive Reset Progress action.
[Full Game purchasing](../Platform/Purchases.md#purchase-feedback) is the narrow
text exception: concise inline pricing, pending-approval, verification, and
restoration outcomes. Keep cancellation quiet and avoid extra alerts over
Apple's purchase authorization.

## Review checklist

Check that input, pending work, and outcomes are distinct; rejected, cancelled,
repeated, and interrupted actions remain truthful; and essential results stay
clear with sound off. Feedback must be proportional and preserve continuous input.
Use [design feedback guidance](../../.agents/skills/apple-design/performance-and-feedback.md)
for mechanics and [Verification](../Platform/Verification.md#choosing-ui-verification)
for evidence selection. This policy does not require a broad audit, new tests, or
simulator execution on every change.

## Why feedback matters

Feedback supports clarity, confidence, recovery, and understandable combat.
Sources: [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/feedback),
[visibility of system status](https://www.nngroup.com/articles/visibility-system-status/),
[Riot's combat-feedback rationale](https://www.riotgames.com/en/news/peeking-valorants-netcode),
and [Xbox perceivability guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103).
These inform design, rather than establishing measured Trinket outcomes.
