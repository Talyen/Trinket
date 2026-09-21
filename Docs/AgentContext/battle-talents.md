# Talent interactions

Authored talents and their short descriptions live in
[the talent manifest](../../ContentManifest/talents.tsv). Talent rule changes
reuse the ordinary damage, healing, control, and resource pipelines. Look up the
named talent only:

- [Balance cadence](#balance-cadence)
- [Damage and control](#damage-and-control)
- [Card preparation and rewards](#card-preparation-and-rewards)
- [Mana and empowerment](#mana-and-empowerment)
- [Healing and overflow](#healing-and-overflow)
- [Removal, protection, and Block](#removal-protection-and-block)
- [Storage ownership](#storage-ownership)

## Balance cadence

### Golden Opportunity and Lucky Charm

Golden Opportunity draws on the first qualifying Gold gain per round. Lucky
Charm Cleanses on the first Gold-granting card per round. A qualifying event
spends its allowance even when no card or negative effect is available.

### First Bloom and Grove Reserve

First Bloom rewards the selected Poison card outcome without requiring a later
Mana-restoring card. Grove Reserve divides unspent Mana by six before ordinary
Block bonuses; a zero base amount grants no Block.

### Loyal Companion

Loyal Companion draws from the Companion's deck when the wearer actually
restores the Companion's Health (overhealing alone does not qualify), at most
once per player turn. Claim the allowance before attempting the draw, even if
no card is available. Normal hand limits, buffering, and control restrictions
apply; healing/draw loops are prevented by the once-per-turn claim.

### Forbidden Knowledge

Forbidden Knowledge pays 1 Health (ordinary Health-cost, no hidden nonlethal
floor, cost before drawing) and draws 2 from the wearer's deck on the existing
alternate-turn cadence beginning on player turn 1. A defeated owner cannot
continue; unavailable draws still spend the Health cost.

### Purifying Aura

Purifying Aura performs one ordinary random Cleanse per living ally every other
player turn beginning on turn 1, through the shared Cleanse pipeline (normal
Cleanse reactions, reaches Burn and Poison). Living owners only; Cleansed
allies must be living (no revive).

### Toxiphage and Cold Hunger

Toxiphage and Cold Hunger roll typed Leech chances through the shared Leech
pipeline, including ongoing damage. Generic and matching typed chances add up
to 100%; damage already granting Leech skips the roll and never Leeches twice.

### Enemy Basic Freeze bonuses

Enemy Basic Freeze bonuses apply once to the initial Basic action, including
Ray of Frost’s immediate pulse, and not to subsequent ongoing damage. This uses
normal Freeze damage and control resolution for both Frost Elemental and Winter Wolf.

## Damage and control

### Thick Hide

Thick Hide retains flat reduction 2, restricted to Physical damage.

### Dazing Swipe

Dazing Swipe rolls 25% per qualifying attack to deal 3 Stun damage through
normal control buildup (ordinary Stun damage and application). The reaction
triggers only on attack hits (not retaliation/periodic) and never recursively
triggers itself.

### Surprise Strike

Surprise Strike guarantees the wearer's first qualifying Physical attack each
combat Critically Hits; preceding non-Physical attacks neither Crit nor spend
the combat allowance.

### Mimic

Mimic deals one additional 2 Bleed damage hit (ordinary Bleed damage and
application) on its first attack only, through the normal damage pipeline;
subsequent hits and ongoing ticks do not repeat the bonus.

### Beastbond

Beastbond restricts its Companion damage bonus to Physical damage (no separate
Physical attack added to non-Physical attacks).

### Noxious Reaction, Serrated Blades, and Blood Money

Damage conversions consume their stored effect before resolving the bonus.
Noxious Reaction spends Poison up to actual Bleed Health damage without
reapplying it. Serrated Blades ticks existing Bleeds with their original
owners and durations; it does not apply another Bleed for each tick. Blood
Money rewards its owner's lethal hit against a Bleeding enemy, including
lethal Bleed detonations, instead of rewarding each damage event.
Turn effects read and commit live state, so later ticks use only the
remaining potency after earlier decay and consumption.

### Paralysis, Bloodrush, and Arcane Focus

Paralysis checks existing Poison on each damaging Poison hit, including
applications and turn ticks. Bloodrush draws a Physical card from its owner's
deck and leaves other cards in place. Arcane Focus's Freeze outcome deals
damage through the normal control-damage pipeline.

### Steam Explosion and Backdraft

Steam Explosion consumes Burn during Freeze-card preparation and adds its
potency to the card's Freeze damage; secondary Freeze reactions do not
activate it. Backdraft consumes Burn on a critical attack and adds its
potency after the Critical Hit multiplier, before defenses, in that hit's
element. Neither conversion detonates Burn or creates another attack.

## Card preparation and rewards

### Quick Fingers

Quick Fingers replaces Golden Touch in the Rogue’s Cutpurse tree while keeping
the saved `rogue_gold_t3_2` unlock. The first positive Gold theft each player turn
draws one card from the wearer’s deck; ordinary Gold gains and another party
member’s theft do not qualify. Claim the allowance before drawing, even if no
card can be drawn. Normal hand limits, buffering, and control restrictions apply.

### Card-triggered reactions

Card-triggered elemental reactions use the selected random outcome. A defeated
card owner cannot continue firing on-play rewards or reactions.

### Next-card preparations

Next-card preparations are captured before a card resolves, refresh instead
of accumulating, and cannot be consumed by the card that created them, even
when it repeats. Typed damage bonuses strengthen an existing unconditional hit
of that type when present, avoiding duplicate equipment bonuses. Sniff Out
shares one party preparation (next ordinary party attack gains 3 Physical on
one original enemy-directed hit; support cards do not reserve; typed Physical,
not a conversion; repeated hits and equipment do not multiply). Predator's
Focus prepares the caster's next attack to Critically Hit and Leech through
the ordinary critical and Leech pipelines (attacks already granting Leech do
not receive duplicate base Leech). Gilded Claws
instead accumulates actual Gold stolen until the next attack. Authored
`Ability.stealsGold` identifies theft from Steal, Bounty Shot, Blackjack,
Tithe, and Bandit's Arrow, and survives outcome resolution and empowerment.

### Shadow Camouflage

Shadow Camouflage grants Panther's normal next-attack Dodge preparation
(evade, refresh not stack, ordinary Dodge reactions on consume) after Panther
plays a non-damaging ordinary card (Sniff Out and Predator's Focus qualify).
Use shared resolved-action classification (Block-absorbed attacks remain
damaging; zero Health loss does not make support; preparing future damage is
not current damage). Automatic abilities and reactions never recursively grant.

### Sleight of Coin and Full House

Sleight of Coin rolls the owner's Critical Hit chance once per Gold card and
doubles its resolved Gold gains, including theft; these are not attack
Critical Hits. Full House carries its set of card types across turns, clears
the set on payout, and does not bank repeated types.

## Mana and empowerment

### Dark Recovery and Arcane Burst

Dark Recovery checks the last-Mana payment before refunds or recovery. Arcane
Burst carries Mana-spend progress across cards and turns, preserving excess
toward its next trigger; its automatic plays do not recursively trigger it.

### Mana Cocoon, Arcane Cleansing, and Chaos Rift

Mana Cocoon, Arcane Cleansing, and Chaos Rift use each actual Mana payment.
Arcane Cleansing removes potency from a randomly chosen present Burn or
Poison effect, without firing Cleanse or natural-expiry reactions. Chaos
Rift divides the payment between two distinct elements from its existing
Freeze, Burn, Poison, and Holy pool; the first receives any odd remainder.

### Dragon’s Patronage and Prismatic Scales

Dragon’s Patronage uses the card owner’s Mana first, then the living patron’s
Mana, then any existing Block-for-Mana substitution. Spending reactions belong
to each actual payer. Prismatic Scales empowers existing Burn and Freeze
damage and supplies a missing element as a damaging hit, charging Mana once.

## Healing and overflow

### Man's Best Friend

Man's Best Friend restores 1 Health to each living ally (no revive) on a
damaging Hero Critical Hit (enemy target, actual Health loss). Healing
Critical Hits target allies (not enemies) and never recursively activate.

### Elemental Leech

Elemental Leech uses the standard Leech rate, including damage-over-time
ticks; it does not add a second base Leech contribution to an already-Leeching
hit. Overhealing keeps its emitted reactions even when no Health is restored.

### Living Archive, Wishspring, and Marrowmend

Living Archive stores half the resolved card healing on the original
recipient until the next party turn. Echoes do not reroll Critical Hits,
reapply healing magnitude bonuses, create further echoes, or revive defeated
recipients. Wishspring uses the original overhealing amount alongside existing
Block and maximum-Health conversions. Marrowmend fills existing Block only to 6.

### Shelter Seed, Masterwork Mixture, and Thorn Shedding

Shelter Seed checks Health before healing and grants only actual restoration
as Thorns. Masterwork Mixture transfers resolved card overhealing only into
the other living ally's missing Health, without rerolling bonuses or bouncing
back. Thorn Shedding consumes Companion Thorns as Poison damage with normal
Poison application; the Companion's own Resonant Shell conversion takes
precedence when both are present.

## Removal, protection, and Block

### Guardian

Guardian grants the Hero 2 Block before an incoming Hero-targeted attack
resolves, once per incoming attack (claimed per action, not per multi-hit
component; ongoing damage never qualifies).

### Warning Bark

Warning Bark preserves one enemy attack per combat (including multi-hit),
routed through Dodge feedback and ordinary Dodge reactions for the protected
target. Claim the combat allowance before resolving reactions.

### Dense Bones

Dense Bones doubles Block absorption capacity against Physical damage only
(other types normal). Use existing combat rounding for partial/odd amounts;
never halve unrelated Health damage.

### Shredding and Retaliatory

Shredding restricts mitigation penetration to Physical damage, preserving
separation from Block penetration. Retaliatory remains Physical damage based
on actual Health lost (despite the internal Thorns trigger name).

### Lightning Rod and Avalanche Guard

Lightning Rod and Avalanche Guard add the existing Block amount without
reapplying outgoing Block bonuses or pacing.

### Lesson Learned and Undying Ember

Lesson Learned protects each cleansed keyword until the next party turn.
Protection prevents reapplication, not the associated damaging hit. Undying
Ember replaces incoming Burn damage with healing during Death’s Door before
Dodge or Block; existing Burn still decays normally.

### Block theft and protection

Block theft transfers only available Block without multiplying the amount.
Light-Fingered uses combat Gold gains, matching the engine’s existing Gold
theft representation. Sealed Sarcophagus protects Block from theft and Purge,
while damage, decay, and voluntary spending remain available.

### Stolen Thunder

Stolen Thunder spends Block once per attack.

### Resonant Shell

Resonant Shell consumes Thorns normally and resolves their damage as Stun with normal buildup.

### Interdict, Blinding Light, and Subzero Mist

Interdict prevents reapplication of the buff kinds actually Purged until the
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
