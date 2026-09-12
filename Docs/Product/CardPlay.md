# Continuous card play

Approved September 12, 2026. This is the standing product specification for
[PD-024](Decisions.md), retained from the approved implementation plan.

## Tap and keep playing

A valid card plays immediately when the player releases their finger. Its lift
and dissolve follow the action; no animation completion gates the next tap.
Holding to inspect, dragging to play, and cancelling a drag remain available.

The hand remains a physical, smoothly reflowing fan. A touch stays attached to
the card originally pressed, and that card stays steady while surrounding cards
move. Drawn, returned, and overflow cards are playable while arriving. A returned
card requires a fresh tap; one gesture cannot play it twice.

Departing manual cards finish independently. Up to six departure visuals may
overlap; under saturation, the oldest fades out. Decorative cards never
intercept touches or affect gameplay.

## Automatic cards stay full-size

Pack Tactics and other automatic effects still visibly draw and play real-sized
cards. Each automatic card sweeps in from its owner's side, reveals its full
artwork above the hand, then casts and dissolves. Entrances and departures may
overlap. These cards do not enter the interactive hand just for presentation,
change its spacing, or become floating text or thumbnails. The hand stays in
front wherever they overlap.

Pack Tactics reads: **Deal 3 Physical damage. Draw and play 1 card from your
ally's deck.** Its opening hit happens first; the ally supplies the follow-up.
Use the caster's deck if the ally is defeated, unable to play, or has no card
available. Other automatic-play abilities retain their existing combat rules.

The whole automatic chain resolves before the next manual card, even when its
visuals are still playing. The player never waits for that visual sequence.

## Turns and battlefield effects

Opening and new-turn cards become playable immediately. Enemy attacks, dealing,
damage, healing, status effects, and ultimate highlights may still be animating.
Health, Mana, status, and availability always show the current resolved state.

Automatic end turn keeps the 0.4-second grace period when no cards are playable.
It does not add a wait for the enemy's attack animation. Ordinary draws,
equipment/talent draws, hidden-buffer promotion, and returned cards follow the
same uninterrupted interaction rules.

## Keep tapping through the finish

When victory or defeat is determined, the result is fixed. While the finishing
battlefield hand is visible, its remaining cards can still be tapped and cast,
including cards that combat rules would otherwise disallow. Preserve those
visual cards even when defeat cleanup removes them from the engine's hand.

These finishing casts are intentionally non-functional: they cause no damage,
healing, resource use, draws, automatic plays, RNG advancement, log entries, or
reward changes. Each card departs once per fresh tap. They do not restart or
extend the result timer. Already-earned automatic-card visuals continue until
the battlefield leaves. Result chrome ends hand interaction.

Card details, the battle log, and backgrounding remain deliberate interaction
pauses. Automatic battle stops when the result is settled.

## Regression protection

Do not classify overlapping casts, immediately playable arriving cards, or
visual-only finishing taps as defects. Restoring animation locks, shrinking
automatic artwork, or blocking finishing taps changes approved product behavior
and requires a new product decision.

[Battle presentation](../AgentContext/battle-presentation.md) owns the engineering
contract and regression coverage. Combat rules remain in BattleEngine; visual
history and finishing taps remain in BattleFeature.
