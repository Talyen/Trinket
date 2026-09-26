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

### Companion chance cadence

Mana-spend draw/refund talents roll once per eligible ability, not per
component. Healing Flames, Flame Shield, Radiant Wisdom,
Purifying Light, Aether Shield, Font of Magic, Living Archive, and Treasure
Hoard use the same ability cadence. Chilling Scales and Blazing Feathers roll
once per enemy ability or natural-damage turn. Venom Spores and Ignition Spark
roll separately at each natural Poison or Burn decay; detonations do not run
those preservation rolls.

Rimewind rolls for each Freeze card hit that removes Health, including both
hits of Ray of Frost.

### Final Companion Talent cadence

Wolf's pack Dodge and Bleed bonuses apply only while Wolf lives. Its first
Physical attack bonus is tracked separately for each ally; Dodge preparations
refresh rather than stack. Bloodrush rolls once per Bleed ability that Critically
Hits. Risen Skeleton's Deathrattle draws on Death's Door entry, allowing the
Door Talents to work together. Weaken Soul refreshes one enemy attack-hit
reduction; ongoing damage cannot consume it.

Mana Moth's Arcane Reservoir and Prismatic Spark roll once per Mana-restoring
ability after actual Mana is restored. Arcane Burst rolls once per empowered
ability. Pixie's Lingering Blessing repeats actual Health restored to one
recipient next turn as resolved healing; that repeat cannot start another
Talent reaction chain. Wishspring prepares a later free Mana empowerment.

Shield Scarab's Radiant Shell rolls on the first qualifying Block absorption
in an incoming ability, reflecting that absorbed amount in one Holy hit. The reflected hit
qualifies for Sun Glyph and Crownfall, each limited to once per turn. Fox's
Snatch, Lucky Strike, and Light-Fingered roll once per eligible ability; its
first successful Gold steal doubles only once per combat. Dodge retaliation
chances roll once per Dodge and preparations refresh rather than stack.
Decoy Swap rolls once per Hero-targeted enemy ability. On success Fox Dodges
the entire ability and reacts once. Piercing Starlight lets Pixie's Holy
attacks ignore half enemy Block; enemies do not currently Dodge.

Paralysis rolls on a Poison attack even when Block absorbs all Health damage.

### Companion Gold and Leech

Haggler adds Gold only to a positive steal by a living Retriever; an empty
steal grants no Gold. Flawless Bounty converts only unallocated excess Leech
restoration on Lizard Scout into Gold, one for one. The gain cannot restore
Health or start another Leech. War Chest adds one percentage point of Hero
Critical Hit chance per Gold gained this combat, subject to the
existing global chance ceiling. Treasure Hoard cannot draw after the enemy
dies.

### Loyal Companion

Loyal Companion draws from the Companion's deck when the wearer actually
restores the Companion's Health (overhealing alone does not qualify), at most
once per player turn. Claim the allowance before attempting the draw, even if
no card is available. Normal hand limits, buffering, and control restrictions
apply; healing/draw loops are prevented by the once-per-turn claim.

### Forbidden Knowledge

Forbidden Knowledge pays 1 Health (ordinary Health-cost, no hidden nonlethal
floor, cost before drawing) and draws 1 from the wearer's deck on the existing
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

Venomous Skin resolves its immediate 1 Poison damage before attaching stacks.
Prismatic Edge's Burn and allied Thorn Shedding's Poison attach only the Health
damage their respective hits actually dealt; fully blocked hits attach none.
Sunwall rolls once per Holy ability and, on success, grants the Companion Block
equal to actual Holy Health damage without applying Block bonuses or pacing
again.

### Physical damage rewards and Burn ticks

Concussive Force and Martial Guard include Physical reaction and periodic damage,
not only attacks. Their proportional rewards use actual Health damage; converted
Block is already resolved and does not receive outgoing Block bonuses again.
Healing Flames and Flame Shield roll once per Burn ability after positive Health
damage. Ember Shield still observes damaging Burn ticks. Fully absorbed ticks
grant no damage rewards.

### Thick Hide

Thick Hide reduces Physical damage by 2 only while its owner has Block.

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

### Phoenix rebirth

From the Ashes now lets Phoenix enter Death's Door on its first fatal hit,
then restores Health. Blazing Rebirth deals its Burn on entry. Afterglow and
Phoenix Vigor fire only if Phoenix survives until Death's Door expires;
Lingering Spirit extends that protection and delays those survival rewards.
Fortified Rebirth and Ashen Ward protect Phoenix only during Death's Door.

## Card preparation and rewards

### Quick Fingers

Quick Fingers draws when the owner's Critical Hit and Gold steal occur in the
same ability. Claim the draw once per ability before drawing; ordinary Gold
gains and another party member's theft do not qualify. Normal hand limits,
buffering, and control restrictions apply.

### Card-triggered reactions

Card-triggered elemental reactions use the selected random outcome. A defeated
card owner cannot continue firing on-play rewards or reactions.
Frost Circuit restores Mana for each Freeze Critical Hit.

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

Aftershock Guard, Winter's Wake, Redline, Ashen Vitality, Golden Guard,
Revealed Flaw, and Sanctified Scroll also reserve their next Block gain,
typed attack, or Critical Hit bonus for a later ability. Multi-hit creating
abilities cannot spend them.

### Panther Dodge preparations

Surprise Strike doubles the next attack after Panther's first Dodge each
combat. Stalker's Precision ignores Block and Vanish guarantees a Critical
Hit on the next attack. Counter Pounce returns 2 Bleed damage on Dodge;
Regroup rolls for one card draw. Preparations refresh instead of stacking.

Lizard Scout's Cold Blood returns Poison on every Dodge; Barbed Tail rolls
once per Dodge for 4 Bleed damage at 20% chance, limiting simultaneous typed
retaliation feedback.

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

Dragon’s Patronage grants 2 Block to Frost Whelp's ally once per Mana-empowered
ability. Mana Moth's Prismatic Scales strengthens existing Burn and Freeze
damage during Mana empowerment, without adding hits or another Mana payment.

## Healing and overflow

### Campfire Comfort

Campfire Comfort restores 2 Health to the lowest-Health living ally at the end
of every other player turn, beginning on turn 1. It skips a fully healed ally.

### Sacrificial Guard and Man's Best Friend

Sacrificial Guard lets Golden Retriever's Block absorb incoming damage to its
Hero ally before the Hero's own Block. Man's Best Friend redirects the first
non-Health-cost fatal damage to the living Retriever once per combat, after
all Block absorption and only when Death's Door cannot protect the Hero. The
redirected damage uses the ordinary damage pipeline;
the intercept is marked as spent before that resolution starts.

### Elemental Leech

Elemental Leech uses the standard Leech rate, including damage-over-time
ticks; it does not add a second base Leech contribution to an already-Leeching
hit. Overhealing keeps its emitted reactions even when no Health is restored.

### Shared Leech

Symbiosis shares a fraction of actual Leech restoration. Shared Feast transfers
only excess Leech restoration from Panther to its living ally. Do not reroll
Critical Hits or apply healing magnitude bonuses a second time.

### Living Archive, Wishspring, and Marrowmend

Living Archive rolls once per Health-restoring ability and gives 3 Thorns to
one healed ally on success. Wishspring uses the original overhealing amount
alongside existing Block and maximum-Health conversions. Marrowmend converts
half the first excess Leech restoration each turn into resolved Block; later
turns can add to existing Block.

### Shelter Seed, Shared Prescription, and Thorn Shedding

Shelter Seed checks Health before healing and grants three Block only after
actual restoration. Shared Prescription offers excess healing to the other
living ally up to their missing Health without applying healing bonuses again,
then Reclaimed Reagents can convert
half the remainder to Block. Thorn Shedding converts either ally's Thorns to
Poison damage with normal Poison application; a Companion's own Resonant Shell
conversion takes precedence.

### Library Owl restoration and Cleanse

Owl's Aether Shield and Living Archive each roll once per restoring ability
after actual Health is gained. A successful roll affects one healed ally:
Aether Shield grants Block equal to their restoration; Living Archive grants
3 Thorns. Font of Magic rolls once when an ability restores Health or Mana,
even when it restores both. Purifying Light's automatic Cleanse uses normal
Cleanse reactions when it succeeds; its 10% chance rolls once per Holy ability.

## Removal, protection, and Block

### Guardian

Guardian grants the Hero 5 Block before the first qualifying Hero-targeted
attack each combat. Ongoing damage and Dodged attacks do not consume it.

### Warning Bark

Warning Bark preserves one enemy attack per combat (including multi-hit),
routed through Dodge feedback and ordinary Dodge reactions for the protected
target. Claim the combat allowance before resolving reactions. The dodged
attack still advances the enemy's ability cadence.

### Dense Bones

Dense Bones doubles Block absorption capacity against Physical damage only
(other types normal). Use existing combat rounding for partial/odd amounts;
never halve unrelated Health damage.

### Shredding and Retaliatory

Shredding restricts mitigation penetration to Physical damage, preserving
separation from Block penetration. Retaliatory remains Physical damage based
on actual Health lost (despite the internal Thorns trigger name).

### Lightning Rod and Aftershock Guard

Lightning Rod adds half the attacker's Block to Stun damage within the existing
hit. Aftershock Guard prepares double Block gain after Bear Stuns an enemy;
the creating ability cannot consume the preparation.

### Lesson Learned and Undying Ember

Lesson Learned protects each cleansed keyword until the next party turn.
Protection prevents reapplication, not the associated damaging hit. Undying
Ember gives Phoenix's outgoing Burn damage Leech only while Phoenix remains on
Death's Door, including its ongoing Burn damage.

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
Steadfast and Perfect Purity also stop Cold Snap from multiplying existing
Freeze build-up while their protection applies.
Blinding Light retains the strongest half-Holy-hit reduction, counting Health
damage and absorbed Block, and spends it across the next enemy attack's hits;
ongoing damage does not consume it. Subzero Mist grants Dodge when the enemy
recovers from Freeze and expires at the next party turn.

## Storage ownership

Trigger and per-combatant talent storage retain value semantics through copy-on-write. Read accessors
borrow stored fields instead of copying the complete trigger set onto the stack;
this matters when attacks resolve nested companion actions.

Operation contracts: [damage](battle-damage.md), [actions](battle-actions.md), [healing](battle-healing.md).
