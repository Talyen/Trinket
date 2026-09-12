# Talent interactions

Authored talents and their short descriptions live in
[the talent manifest](../../ContentManifest/talents.tsv). Talent rule changes
reuse the ordinary damage, healing, control, and resource pipelines.

## Balance cadence

- Golden Opportunity draws on the first qualifying Gold gain per round. Lucky
  Charm Cleanses on the first Gold-granting card per round. A qualifying event
  spends its allowance even when no card or negative effect is available.
- First Bloom rewards the selected Poison card outcome without requiring a later
  Mana-restoring card. Grove Reserve divides unspent Mana by six before ordinary
  Block bonuses; a zero base amount grants no Block.
- Shadow Camouflage prepares one generic damage on Panther’s next attack after
  an enemy turn without an attack against Panther. Dodged and fully Blocked attacks
  count; ongoing damage and aura pulses do not. Skipped enemy turns qualify.
  The preparation refreshes instead of stacking and survives until consumed.
- Toxiphage and Cold Hunger roll typed Leech chances through the shared Leech
  pipeline, including ongoing damage. Generic and matching typed chances add up
  to 100%; damage already granting Leech skips the roll and never Leeches twice.

Enemy Basic Freeze bonuses apply once to the initial Basic action, including
Ray of Frost’s immediate pulse, and not to subsequent ongoing damage. This uses
normal Freeze damage and control resolution for both Frost Elemental and Winter Wolf.

## Damage and control

- Damage conversions consume their stored effect before resolving the bonus.
  Noxious Reaction spends Poison up to actual Bleed Health damage without
  reapplying it. Serrated Blades ticks existing Bleeds with their original
  owners and durations; it does not apply another Bleed for each tick. Blood
  Money rewards its owner's lethal hit against a Bleeding enemy, including
  lethal Bleed detonations, instead of rewarding each damage event.
  Turn effects read and commit live state, so later ticks use only the
  remaining potency after earlier decay and consumption.
- Paralysis checks existing Poison on each damaging Poison hit, including
  applications and turn ticks. Bloodrush draws a Physical card from its owner's
  deck and leaves other cards in place. Arcane Focus's Freeze outcome deals
  damage through the normal control-damage pipeline.
- Steam Explosion consumes Burn during Freeze-card preparation and adds its
  potency to the card's Freeze damage; secondary Freeze reactions do not
  activate it. Backdraft consumes Burn on a critical attack and adds its
  potency after the Critical Hit multiplier, before defenses, in that hit's
  element. Neither conversion detonates Burn or creates another attack.

## Card preparation and rewards

- Quick Fingers replaces Golden Touch in the Rogue’s Cutpurse tree while keeping
  the saved `rogue_gold_t3_2` unlock. The first positive Gold theft each player turn
  draws one card from the wearer’s deck; ordinary Gold gains and another party
  member’s theft do not qualify. Claim the allowance before drawing, even if no
  card can be drawn. Normal hand limits, buffering, and control restrictions apply.

- Card-triggered elemental reactions use the selected random outcome. A defeated
  card owner cannot continue firing on-play rewards or reactions.
- Next-card preparations are captured before a card resolves, refresh instead
  of accumulating, and cannot be consumed by the card that created them, even
  when it repeats. Typed damage bonuses strengthen an existing unconditional hit
  of that type when present, avoiding duplicate equipment bonuses. Gilded Claws
  instead accumulates actual Gold stolen until the next attack. Authored
  `Ability.stealsGold` identifies theft from Steal,
  Bounty Shot, Blackjack, and Tithe, and survives outcome resolution and empowerment.
- Sleight of Coin rolls the owner's Critical Hit chance once per Gold card and
  doubles its resolved Gold gains, including theft; these are not attack
  Critical Hits. Full House carries its set of card types across turns, clears
  the set on payout, and does not bank repeated types.

## Mana and empowerment

- Dark Recovery checks the last-Mana payment before refunds or recovery. Arcane
  Burst carries Mana-spend progress across cards and turns, preserving excess
  toward its next trigger; its automatic plays do not recursively trigger it.
- Mana Cocoon, Arcane Cleansing, and Chaos Rift use each actual Mana payment.
  Arcane Cleansing removes potency from a randomly chosen present Burn or
  Poison effect, without firing Cleanse or natural-expiry reactions. Chaos
  Rift divides the payment between two distinct elements from its existing
  Freeze, Burn, Poison, and Holy pool; the first receives any odd remainder.
- Dragon’s Patronage uses the card owner’s Mana first, then the living patron’s
  Mana, then any existing Block-for-Mana substitution. Spending reactions belong
  to each actual payer. Prismatic Scales empowers existing Burn and Freeze
  damage and supplies a missing element as a damaging hit, charging Mana once.

## Healing and overflow

- Elemental Leech uses the standard Leech rate, including damage-over-time
  ticks; it does not add a second base Leech contribution to an already-Leeching
  hit. Overhealing keeps its emitted reactions even when no Health is restored.
- Living Archive stores half the resolved card healing on the original
  recipient until the next party turn. Echoes do not reroll Critical Hits,
  reapply healing magnitude bonuses, create further echoes, or revive defeated
  recipients. Wishspring uses the original overhealing amount alongside existing
  Block and maximum-Health conversions. Marrowmend fills existing Block only to 6.
- Shelter Seed checks Health before healing and grants only actual restoration
  as Thorns. Masterwork Mixture transfers resolved card overhealing only into
  the other living ally's missing Health, without rerolling bonuses or bouncing
  back. Thorn Shedding consumes Companion Thorns as Poison damage with normal
  Poison application; the Companion's own Resonant Shell conversion takes
  precedence when both are present.

## Removal, protection, and Block

- Lightning Rod and Avalanche Guard add the existing Block amount without
  reapplying outgoing Block bonuses or pacing.
- Lesson Learned protects each cleansed keyword until the next party turn.
  Protection prevents reapplication, not the associated damaging hit. Undying
  Ember replaces incoming Burn damage with healing during Death’s Door before
  Dodge or Block; existing Burn still decays normally.
- Block theft transfers only available Block without multiplying the amount.
  Light-Fingered uses combat Gold gains, matching the engine’s existing Gold
  theft representation. Sealed Sarcophagus protects Block from theft and Purge,
  while damage, decay, and voluntary spending remain available. Stolen Thunder
  spends Block once per attack; Resonant Shell consumes Thorns normally and
  resolves their damage as Stun with normal buildup.
- Interdict prevents reapplication of the buff kinds actually Purged until the
  next party turn, including Block but excluding instant healing and resources.
  Blinding Light retains the strongest half-Holy-hit reduction, counting Health
  damage and absorbed Block, and spends it across the next enemy attack's hits;
  ongoing damage does not consume it. Subzero Mist grants Dodge when the enemy
  recovers from Freeze and expires at the next party turn.

## Storage ownership

Trigger and per-combatant talent storage retain value semantics through copy-on-write. Read accessors
borrow stored fields instead of copying the complete trigger set onto the stack;
this matters when attacks resolve nested companion actions.

Operation contracts: [damage](battle-damage.md), [actions](battle-actions.md), [healing](battle-healing.md).
