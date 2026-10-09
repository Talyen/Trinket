# Continuous card play

Approved September 12, 2026. This is the standing product specification for
[PD-024](Decisions.md), retained from the approved implementation plan.

## Tap and keep playing

A valid card plays immediately when the player releases their finger. Its lift
and dissolve follow the action; no animation completion gates the next tap.
The departing card rises quickly, then eases upward through the artwork's
dissolve, travelling 55% of its height with the existing departure duration.
Holding to inspect, dragging to play, and cancelling a drag remain available.

Touch-down immediately lifts the card with a small enlargement and shadow.
Movement follows the finger from its original grab position in a stable hand
coordinate space; the tap-versus-drag threshold does not delay visual pickup.
Only lift and return animate independently of the finger's movement.
A restrained edge marks playable cards, with one settling accent when a card
becomes playable. Crossing the drag-to-play threshold adds no border animation,
glow, enlargement, or haptic. Availability cues never dim the artwork, repeat
continuously, or delay an action.

Inspection uses native long-press recognition with a 0.5-second hold and a
10-point movement tolerance. Reaching 10 points of displacement cancels both
inspection and tap activation for that touch, even if the finger returns to its
starting position. Inspection consumes the touch; releasing never plays the card.
The nonvisual “Inspect card” accessibility action offers the same details.

A drag plays only when released at least 80 points upward and farther upward
than sideways. Predicted flick travel and earlier threshold crossings do not
commit a card. Returning inside that boundary cancels the play. Interrupted
touches return the card without playing or reopening inspection.

The hand remains a physical, smoothly reflowing fan. A touch stays attached to
the card originally pressed, and that card stays steady while surrounding cards
move. Drawn, returned, and overflow cards are playable while arriving. A returned
card requires a fresh tap; one gesture cannot play it twice.

Departing manual cards finish independently. Up to six departure visuals may
overlap; under saturation, the oldest fades out. Decorative cards never
intercept touches or affect gameplay.

With the autoplay toggle enabled, cards commit immediately from their resting
hand position and use the same rise and dissolve as tap-to-play. There is no
separate pre-lift or play delay. Autoplay starts the next card after 0.85 seconds,
allowing the final 0.15 seconds of the one-second departure visuals to overlap. It pauses for manual interaction,
while manual plays remain available during those casts.
Autoplay keeps its sequenced combat feedback.

## Automatic cards stay full-size

Effects that automatically draw and play cards still show full-sized artwork above
the hand before casting. They do not enter the interactive hand for presentation.
Automatic chains finish in the engine before the next manual card, without waiting
for their visuals.

Pack Tactics and Shadowstep instead draw playable cards into the hand. Pack Tactics
reads: **Deal 3 Physical damage. Draw a card from your ally's deck.** Its opening
hit happens first; normal ally-deck fallback rules apply. Shadowstep reads:
**Draw a card. Dodge the next attack against you.** Neither casts its drawn card.
New and returned cards preserve arrival order and immediate interaction while
joining the hand, with the ordinary three-card fan and FIFO overflow promotion.

## Turns and battlefield effects

Opening and new-turn cards become playable immediately. Enemy attacks, dealing,
damage, healing, and status effects may still be animating.
Health, Mana, status, and availability always show the current resolved state.

Combatant attacks retain a visible wind-up, swing, and recovery for taps,
drags, automatic cards, and enemy actions. Manual tap attacks prepare for 0.025
seconds, swing for 0.075 seconds, and recover for 0.300 seconds. Prepared drags
skip preparation and share that swing and recovery. Automatic and enemy attacks
retain their 0.40-second preparation, 0.15-second swing, and 0.45-second recovery.
Rapid attacks shorten preparation and overlap recovery to keep pace. Dragging
holds preparation until release and settles back on cancellation.

Manual card results appear immediately on successful finger release: floating
text, sounds, result haptics, and target recoil never wait for an earlier
animation. Healing and support reactions are immediate too. The attacker
continues its motion without replaying feedback at impact. Triggered cards,
counterattacks, enemy actions, and auto-battle retain sequenced feedback.
Separate attacks retain distinct impacts; simultaneous components of one
attack share the strongest recoil. Fully blocked direct hits recoil visibly
with Block styling. Damage-over-time ticks remain quiet. These are presentation
beats only: the engine and current resources never wait for them.

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
