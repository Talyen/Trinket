# Action, card and Mana contracts

Use with [engine ownership](battle-engine.md) for action identity, hands, preparations or Mana payments.

`CombatantRuntime.talents` groups battle, turn, pending, timed, and action
state explicitly behind copy-on-write storage. Turn start clears only turn state
and expired timed bonuses; pending effects survive until their consuming operation.
Keep an amount and its expiry/source together. The last-action empowerment
receipt retains its existing execution checkpoint.
Next-turn Dodge boosts from Pack Coordination and Smoke Screen live in turn
state so a longer Cleanse bonus cannot extend them.

Playful Energy counts both partners' cards and heals once when the party reaches
its threshold. Shared next-card Dodge bonuses refresh rather than stack; card preparation
reserves it, and only that card's first damaging hit can spend it. A support card
uses the preparation without carrying it forward to another card.
`CombatResolution` owns party preparations and their per-card reservations.
Immediate card damage carries action/card provenance independently of damage
mechanics, including the first pulse of a recurring effect. Later ticks and
reaction damage cannot spend that reservation.

`CombatResolution` owns nested action/card identity, selected outcomes, automatic-play
ancestry, cadence claims, and associated mutable talent action/card bookkeeping.
Do not maintain parallel talent stacks or edit frame arrays from handlers; use its
preparation, consumption, and completion operations. `ResolvedActionFacts` is an immutable shared record:
card reactions, talents, and Uniques read its selected outcome and qualifying
keywords, while talent execution results track what actually happened separately.
Capture facts at preparation; evaluate later operation conditions at their existing
execution checkpoints. Do not classify a played card from `possibleOperations` or
reconstruct its outcome from another talent's bookkeeping. Keep these immutable
records shared so nested actions do not copy their full payload onto the stack.
`BattleActionContext` likewise shares immutable participants while preserving value
equality; payment receipts and checkpoint eligibility retain actor IDs.
Independent passive restoration operations have separate talent-roll allowances;
nested restoration reactions share their parent allowance. Card and action
restoration still use their existing per-card and per-action claims.

Ability definitions share immutable storage so nested automatic casts and combat
snapshots do not copy the complete definition through each stack frame.
`Ability.operations` is the authoritative ordered traversal for classification,
empowerment, descriptions, and execution; `possibleOperations` includes unresolved
outcomes. Deterministic conditional outcomes resolve once at action preparation,
without RNG, and card assessment uses the same selection before quoting costs.
Random outcomes remain separate. Conditional guaranteed criticals snapshot their
eligibility at preparation. `BattleActionContext`
binds the selected target for an action and resolves allies/opponents relative to
its actor. A defeated actor cannot continue; a winning card may still resolve its
remaining support rewards. New actions cannot start after battle ends.

Combat logs summarize committed damage by recipient and keyword, with self-paid
Health costs reported separately. Damage packets and their summary share the
resolved action identity so nested actions do not combine their totals.
Support-only log summaries do not assign the selected attack target to allied
effects; committed effect events identify their actual recipients. Direct Mana
gain summaries report the actual restoration after capacity limits and bonuses.
Gold effect summaries use the ability's theft marker: Golden Plate gains Gold,
while Steal and the other theft cards steal it. Gold summaries report the actual
grant after equipment and talent bonuses.

End-of-player-turn talents resolve before the enemy action. Mana Shield's Block
can absorb that action, and end-turn healing and Cleanse finish before it begins.
Round effects and passive Block decay follow the enemy action.

`payMana` returns a `ManaPayment` with actual before/after balances. Capture every
contribution to an empowerment purchase before payment reactions; last-Mana rules
read receipts even after refunds or nested actions. A prepared empowerment discount
applies to one purchase; Meteor and Falling Star can then buy their normal paid
repeats. A reaction that ends combat stops further empowerment purchases.
Permanently free empowerment remains bounded to one purchase.
Arcane Burst keeps excess
progress across cards and turns separately from cadence claims. Periodic rewards
use `playerTurnNumber` and `isPlayerTurn(every:startingAt:)`; stored `turnCount`
remains zero-based.

## Hand contract

Each player turn schedules three ordinary draws, including the opening turn.
Hero–Companion–Hero alternates with Companion–Hero–Companion; effect draws do not
advance this sequence. Each owner starts with one shuffled Basic, Skill, and
Ultimate. A sole living party member receives all scheduled draws; blocked or
empty decks do not borrow the living partner's draw. Cards remain in arrival order.

Visible hand caps at **three** cards (`BattleHand.maxSize`); overflow draws enqueue
a hidden FIFO buffer and promote after effects / end-turn draws. Unplayed cards
survive turn changes. Played physical copies enter their owner's discard pile in
play order, before resolving effects. After the enemy turn and round effects,
discards append behind undrawn cards before new-turn draws. Empty draw piles never
refill mid-turn; decks do not reshuffle after battle start.

Pack Tactics deals 3 Physical damage, then draws a manual card from the caster's
ally's deck. It falls back to the caster's deck when the ally is defeated, blocked
from drawing, unable to pay the drawn card's Health cost, or has no card to draw.
Shadowstep draws a manual card from the caster's deck and prepares Dodge; a missing
card does not borrow the partner's. Other draw-and-play effects retain automatic
play and their existing alternating-deck rules.

Unique returns move the exact physical copy from discard or draw pile into hand,
never adding another deck copy. The Returning Flight returns the first Physical
card once per wearer per player turn. The Returning Gale recovers the last ordinary
copy on Dodge at most once per wearer per player-turn cycle, including the enemy
turn. Both allowances reset at the next player-turn start. Presentation IDs are
fresh on arrival while the physical copy's identity survives draws and returns.
Full equipment rules live in [Unique equipment](../Product/UniqueItems.md).

Dance of Blades continues its draw-and-play chain only after the drawn attack
Critically Hits; critical healing or Leech restoration cannot extend it.

Combatant effect details include active talent preparations and readied Unique
powers, including Wrenflight's temporary Dodge and accumulated Golden Crucible
damage. Entries follow the same consumption and expiry rules as their bonuses.
Full automatic Basic abilities use ordinary attack damage talents such as Razor
Claws, Ground Slam, and Battering Ram; card-only cadences retain their restrictions.

Consolation Prize creates one uniformly random card from `AbilityCatalog.all` on
the owner's first fully Blocked attack per combat. Claim before generation; the
new copy belongs to that owner, respects FIFO overflow, and follows ordinary
cycling for this battle without changing the saved loadout. Battle preparation
pins the possible card artwork only when Consolation Prize is equipped, preserving
immediate card play without mid-battle on-demand decoding.

Presentation layout (3:4 art, no top chrome, health anchors): [TrinketBattleFeature README](../../Packages/TrinketBattleFeature/README.md).

Turn and opening-hand drivers can record immutable presentation checkpoints while
finishing all engine work synchronously. Incremental draw helpers are package-only.
Operation and mutation contracts live in [battle-engine context](battle-engine.md);
playback and command readiness live in [battle presentation](battle-presentation.md).

`BattleState.assessCard(_:)` provides read-only availability, certain effect
recipients, and resource-use quotes for the battle interaction cues. It shares
affordability, possible outcomes, targeting, and the Mana empowerment budget with
resolution. Assessment never advances RNG or consumes combat preparations.
Automatic-play recipients remain unresolved until their drawn actions execute.
Targets that depend on preceding effects remain unresolved; Panacea exposes
its separate cleanse and healing recipients unless Fresh Batch can change the
healing recipient after Cleanse. Branch-dependent costs and reactive repeated payments remain non-quantitative;
only resolved combat events establish the result. The legacy
`heldCardNextAttackDamage` trigger is retained for saved-item conversion in
`InventoryItem.resolvedPower(at:)`, not as an active combat rule.

For a named talent change, look up its rule in [talent interactions](battle-talents.md).

Use `withAutomaticPlay` for automatic chains; counterattack ancestry follows its
action frame. Do not toggle a separate automatic-play flag.

## Ability strategy

- Avatar reserves its Holy conversion at the next direct attack's first eligible
  hit, before reactions. All direct hits in that action share it; nested attacks
  and recurring damage cannot spend that reservation. A fresh Avatar preparation
  granted during the action survives for the next attack.
- Shield Bash gains 1 Block, then deals Stun damage equal to half the actor's
  current Block, floored and clamped to a minimum of 1. The gain happens before
  the damage calculation and no Block is spent.
- Ice Shot deals 2 Freeze damage, doubled against an already Frozen target.
  It preserves Frozen and remains Freeze damage for empowerment and identity.
- Maul chooses 3 Stun against positive enemy Block or 3 Bleed otherwise; it is
  not random. Stab guarantees a Critical Hit against full Health at preparation
  and otherwise uses ordinary critical chance, without its former +25% bonus.
- Sunder halves Block before its 4 Physical hit, using existing halving rounding.
- Sniff Out deals 1 Bleed damage, then prepares +1 generic damage for the living
  partner, falling back to the caster if the partner is defeated. Reapplication
  refreshes rather than stacks;
  preparation survives turn changes. Only the recipient's next damaging card
  reserves it, including automatically played cards. The first damaging hit
  consumes the reservation once; support cards, the other partner's attacks,
  periodic damage, and counterattacks cannot spend it. The recipient owns the
  visible preparation and detail summary, independently of the source's survival.

Cold Snap deals Freeze damage before checking Frozen for its draw; newly applied
Frozen qualifies. Blood Offering pays 2 Health, deals 1 Bleed, then draws a card.
