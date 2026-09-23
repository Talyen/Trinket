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

Golden Opportunity draws on the first qualifying Gold gain per round. Wildcard's
Lucky Charm rolls once per Gold-gaining ability and Cleanses one negative status
effect only when the roll succeeds and the owner has a removable effect.

### Arcane Thorns, Living Conduit, and Grove Reserve

Arcane Thorns rewards actual Mana restoration. Living Conduit converts excess
Mana restoration into Thorns, including when Mana starts full; it does not
require a Mana-using Companion. Grove Reserve gives the Companion passive Dodge
while the owner has unspent Mana.

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
the initial pulse of recurring damage, and not to subsequent ongoing damage. This uses
normal Freeze damage and control resolution for both Frost Elemental and Winter Wolf.

## Damage and control

### Poison riders and damage conversions

Venomous Skin resolves its immediate Poison damage before attaching stacks.
Prismatic Edge's Burn and allied Thorn Shedding's Poison attach only the Health
damage their respective hits actually dealt; fully blocked hits attach none.
Sunwall rolls once per Holy ability and, on success, grants the Companion Block
equal to actual Holy Health damage without applying Block bonuses or pacing
again.

### Physical damage rewards and Burn ticks

Concussive Force and Martial Guard include Physical reaction and periodic damage,
not only attacks. Their proportional rewards use actual Health damage; converted
Block is already resolved and does not receive outgoing Block bonuses again.
Healing Flames, Flame Shield, and Ember Shield also observe damaging Burn ticks.
Fully absorbed ticks grant no damage rewards.

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

Noxious Reaction prepares one guaranteed Bleed Critical Hit after a Poison
Critical Hit. Serrated Blades extends Bleed applied by a Critical Hit without
creating an extra damage event. Blood Money rewards its owner's lethal hit
against a Bleeding enemy, including lethal Bleed detonations, instead of
rewarding each damage event.

### Bloodfire

Bloodfire rolls once per Burn ability, on its first Burn attack hit. A success
deals 4 immediate Bleed damage through the ordinary Block and damage pipeline
and emits one automatic damage cue;
ongoing Burn damage does not roll again.

### Paralysis, Bloodrush, and Arcane Focus

Paralysis checks existing Poison on each damaging Poison hit, including
applications and turn ticks. Bloodrush draws a Physical card from its owner's
deck and leaves other cards in place. Arcane Focus adds one damage to Mana
empowerment without creating another elemental hit.

### Steam Explosion and Backdraft

Steam Explosion consumes Burn during Freeze-card preparation and adds its
potency to the card's Freeze damage; secondary Freeze reactions do not
activate it. Backdraft increases Critical Hit damage against Burning enemies
within the existing hit.

## Card preparation and rewards

### Quick Fingers

Quick Fingers draws when the owner's Critical Hit and Gold steal occur in the
same ability. Claim the draw once per ability before drawing; ordinary Gold
gains and another party member's theft do not qualify. Normal hand limits,
buffering, and control restrictions apply.

### Card-triggered reactions

Card-triggered elemental reactions use the selected random outcome. A defeated
card owner cannot continue firing on-play rewards or reactions.

### Next-card preparations

Next-card preparations are captured before a card resolves, refresh instead
of accumulating, and cannot be consumed by the card that created them, even
when it repeats. Typed damage bonuses strengthen an existing unconditional hit
of that type when present, avoiding duplicate equipment bonuses. Sniff Out's
recipient-owned preparation follows the [ability strategy contract](battle-actions.md#ability-strategy).
Predator's
Focus deals 1 Bleed and prepares the caster's next attack with Leech.
Gilded Claws
instead accumulates actual Gold stolen until the next attack. Authored
`Ability.stealsGold` identifies theft from Steal, Bounty Shot, Blackjack,
and Tithe; the marker survives outcome resolution and empowerment.

### Shadow Camouflage

Shadow Camouflage grants Panther's normal next-attack Dodge preparation
(evade, refresh not stack, ordinary Dodge reactions on consume) after Panther
plays a non-damaging ordinary card. Sniff Out and Predator's Focus now deal
damage and do not qualify.
Use shared resolved-action classification (Block-absorbed attacks remain
damaging; zero Health loss does not make support; preparing future damage is
not current damage). Automatic abilities and reactions never recursively grant.

### Sleight of Coin and Jackpot

Sleight of Coin prepares +15% Dodge for the rest of the turn after a successful
Gold steal; repeated steals refresh rather than stack it. Jackpot folds its
extra Gold into a Critical Hit's Gold steal, producing one Gold gain event.

### Consolation Prize and Feigned Miss

Consolation Prize grants 3 Gold on the first fully Blocked attack each combat.
Feigned Miss prepares double damage for the next Physical attack after an
attack is fully Blocked. Neither reward requires the blocked attack to deal
Health damage, and a later hit in the same ability cannot spend the preparation.

## Mana and empowerment

Overcharge and Soul Burn prepare bonuses for a later attack. Their preparing
ability cannot consume the bonus, even when it has multiple hits.

### Dark Recovery and Arcane Burst

Dark Recovery increases Leech healing while the owner has no Mana. Arcane
Burst carries Mana-spend progress across cards and turns, preserving excess
toward its next trigger; its automatic plays do not recursively trigger it.
Draw-and-play effects and Phantom Counter retain automatic ancestry throughout
nested payments and card reactions.

### Mana Cocoon, Arcane Cleansing, and Chaos Rift

Mana Cocoon uses each actual Mana payment. Arcane Cleansing performs an ordinary
Cleanse when its owner ends a turn at zero Mana. Chaos Rift increases damage
from Mana-empowered Critical Hits within the existing hit.

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

### Shared Leech

Symbiosis and Companion-to-Hero Leech sharing transfer a fraction of actual
restoration as resolved healing. Do not reroll Critical Hits or apply healing
magnitude bonuses a second time; ordinary recipient eligibility still applies.

### Living Archive, Wishspring, and Marrowmend

Living Archive stores half the resolved card healing on the original
recipient until the next party turn. Echoes do not reroll Critical Hits,
reapply healing magnitude bonuses, create further echoes, or revive defeated
recipients. Wishspring uses the original overhealing amount alongside existing
Block and maximum-Health conversions. Marrowmend fills existing Block only to 6.

### Shelter Seed, Shared Prescription, and Thorn Shedding

Shelter Seed checks Health before healing and grants three Block only after
actual restoration. Shared Prescription offers excess healing to the other
living ally up to their missing Health without applying healing bonuses again,
then Reclaimed Reagents can convert
half the remainder to Block. Thorn Shedding converts either ally's Thorns to
Poison damage with normal Poison application; a Companion's own Resonant Shell
conversion takes precedence.

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

Lightning Rod adds half the attacker's Block to Stun damage within the existing
hit. Avalanche Guard still duplicates existing Block without reapplying Block
bonuses or pacing.

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
