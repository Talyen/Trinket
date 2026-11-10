# Card play

This is the standing product specification for [PD-024](Decisions.md).

## Tap and keep playing

A valid card plays on release, or joins an ordered queue if another hand cast
started less than 0.5 seconds ago. Queued cards lift in the hand and give immediate
haptic feedback; each plays once when its turn arrives if it is still available.
A queued card that remains in the hand but is no longer playable settles back with a denial sound.
A queued card does not carry over to a later turn.
Each cast keeps its full one-second departure animation, overlapping the next cast
rather than shortening the animation. Repeated taps on a queued card do not queue it twice.
The departing card rises quickly, then eases upward through the artwork's
dissolve, travelling 55% of its height with the existing departure duration.
Holding to inspect, dragging to play, and cancelling a drag remain available.

Touch-down immediately lifts the card with a small enlargement and shadow. Damage
cards also begin the attacker’s wind-up; cancellation or inspection smoothly
returns the attacker to rest.
Movement follows the finger from its original grab position in a stable hand
coordinate space; the tap-versus-drag threshold does not delay visual pickup.
Only lift and return animate independently of the finger's movement.
A restrained steady edge marks playable cards, with an animated visibility
transition. Becoming playable or dismissing inspection does not pulse the border.
Crossing the drag-to-play threshold adds no border animation,
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

Decorative cards never intercept touches or affect gameplay.

With the autoplay toggle enabled, cards use the same release geometry, rise,
dissolve, and particle timing as an ordinary tap. Autoplay waits for the one-second
card departure before choosing the next card. Equal-scored choices rotate through
the hand; stronger and battle-finishing choices keep priority. Autoplay pauses for
manual interaction and queued manual cards; manual cards use the same queue during those casts.
Combat feedback keeps its normal sequencing.

After thirty rounds without new enemy Health depletion, Auto Battle pauses with
an inline Play Manually / Retreat choice. It preserves the remembered Auto
preference, keeps manual cards available, and never declares defeat. Re-enabling
Auto starts a fresh progress window; slow fights continue while making progress.

## Automatic cards stay full-size

Effects that automatically draw and play cards still show full-sized artwork above
the hand before casting. They do not enter the interactive hand for presentation.
Automatic chains finish in the engine before the next manual card, without waiting
for their visuals.

Pack Tactics and Shadowstep instead draw playable cards into the hand. Pack Tactics
reads: **Deal 5 Physical damage. Draw a card from your ally's deck.** Its opening
hit happens first; normal ally-deck fallback rules apply. Shadowstep reads:
**Deal 4 Physical damage. Draw 1 card.** Its hit precedes the caster-deck draw;
it grants neither Dodge nor a card repeat. Neither ability casts its drawn card.
New and returned cards preserve arrival order and normal interaction while
joining the hand, with the ordinary three-card fan and FIFO overflow promotion.

## Turns and battlefield effects

Opening and new-turn cards become playable immediately. Enemy attacks, dealing,
damage, healing, and status effects may still be animating.
Card availability follows the current resolved state. Health, Mana, status artwork,
and defeat artwork update with the action’s impact feedback.

This section owns approved attack timing; [CombatFeedbackAttackRecipes.swift](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/CombatFeedbackAttackRecipes.swift)
implements the motion recipes.

Combatant attacks retain a visible wind-up, swing, and recovery for taps,
drags, automatic cards, and enemy actions. Party attacks prepare for 0.10 seconds,
including time spent pressing the card; enemy attacks prepare for 0.40 seconds. All attacks share a 0.15-second swing and
0.45-second recovery. Prepared drags
skip preparation and share that swing and recovery.
Rapid attacks shorten preparation to a 0.08-second cap and overlap recovery to
keep pace. Dragging holds preparation until release and settles back on cancellation.

Manual cards commit on successful finger release or when a queued tap is admitted.
Their floating results, sounds, result haptics, target recoil,
status artwork, and resource bars appear together at the action’s apex. Triggered
cards, counterattacks, enemy actions, and auto-battle use that same impact timing.
Support results use their scheduled action cue. Victory celebration follows the
visible lethal hit.
Damage numbers launch at impact even when other feedback is present; spatial routing
separates simultaneous results. Separate attacks retain distinct impacts;
simultaneous components of one attack share the strongest recoil. Fully blocked
direct hits recoil visibly with Block styling. Damage-over-time ticks remain quiet. These are presentation
beats only: the engine and current resources never wait for them.

Automatic end turn keeps the 0.4-second grace period when no cards are playable.
It does not add a wait for the enemy's attack animation. Ordinary draws,
equipment/talent draws, hidden-buffer promotion, and returned cards follow the
same card input rules.

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

Preserve full-size automatic artwork, ordered responsive manual input, complete
cast animations, and visual-only finishing taps.

[Battle presentation](../AgentContext/battle-presentation.md) owns the engineering
contract and regression coverage. Combat rules remain in BattleEngine; visual
history and finishing taps remain in BattleFeature.
