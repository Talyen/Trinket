# Talent interactions

Authored talents and their short descriptions live in
[the talent manifest](../../ContentManifest/talents.tsv). Talent rule changes
reuse the ordinary damage, healing, control, and resource pipelines. Look up the
named talent only. Resolve its current trigger from the manifest; an engine
helper's fallback display name may describe an older, distinct trigger. Authored catalogs
own current amounts and chances; this guide retains ordering, eligibility,
trigger limits, conversions and compatibility rules.

- [Balance cadence](#balance-cadence)
- [Damage and control](#damage-and-control)
- [Card preparation and rewards](#card-preparation-and-rewards)
- [Mana and empowerment](#mana-and-empowerment)
- [Healing and overflow](#healing-and-overflow)
- [Removal, protection, and Block](#removal-protection-and-block)
- [Distinct engine triggers](#distinct-engine-triggers)
- [Storage ownership](#storage-ownership)

## Balance cadence

### Victory Gold and theft

Lucky Break draws a card on its owner's first positive actual Gold gain each turn,
including theft. Zero or rejected grants do not spend its turn allowance.

Dig for Treasure adds a percentage bonus to victory Gold scaling over encounter
Gold plus combat gains, before spending. The selected party's bonus is captured
at launch and survives Companion defeat. It uses ordinary reward remainders,
capacity, and receipt handling; noncombat rewards and defeat payouts exclude it.
Light Fingers steals Gold on attack Critical Hits, including fully Blocked hits
and full Basic counterattacks, after the source survives retaliation. Critical
healing, ongoing damage, and raw reactions do not qualify. Palmed Coin rolls for
theft after Dodge. Both use ordinary theft reactions;
there is no enemy Gold purse or new activation allowance.

### Shared Poison and Burn pools

Contagion, Lingering Toxin, Venom Spores, Smoldering, Slow Burn, Ignition Spark,
and Ember Persistence affect enemy pools while their owners live, independently
of the original applier. Each property takes the strongest living Talent value;
matching preservation Talents do not add. Legacy source-owned fields and original
damage credit remain separate. Preservation precedes growth (+1 potency), and
natural-turn rolls never run during detonation.

### Reproving Light, Perfect Purity, and Loaded Strike

Reproving Light deals one ordinary Holy damage reaction per successful Cleanse
operation, regardless of removed debuff count. Empty removals and nested
Hero-Talent reactions do not grant another hit. Legacy debuff-reflection profiles
retain their existing rules.
Perfect Purity requires an actual debuff removal and protects the cleansed
recipient until the next player turn; it does not prevent associated damage.
Loaded Strike rolls once per attack action to double damage,
sharing the outcome across that action's hits regardless of damage type; otherwise damage is unchanged.
Counterattacks own their roll; ongoing and raw reaction damage do not qualify.
Clean Cut makes Critical Hits of every damage type ignore enemy Block.
Legacy `standardDeviation` retains its separate Physical double/half rule and upward rounding.

### Golden Opportunity and Lucky Charm

Fox's Golden Opportunity doubles its first positive Gold steal each combat. Wildcard's
Lucky Charm rolls once per Gold-gaining ability and Cleanses one negative status
effect only when the roll succeeds and the owner has a removable effect.
Last Wager and Health is Wealth share that cadence. Counterattack Basics retain
one allowance across separate Critical Hit Gold and theft gains; standalone Gold
rewards retain their independent reactions.
Coinmail converts only its owner's Gold gains using ordinary combat rounding,
including Fickle Fortune's odd Gold gains. Its converted Block is
resolved: it does not repeat Block bonuses or fight pacing, and preserves prepared
bonuses for the next base Block grant. It does not suppress an
independent Gold-earned Block threshold retained in saved equipment.

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
Snatch and Lucky Strike roll once per eligible ability. Light-Fingered steals half
the enemy's current Block, truncating the stolen amount, on Fox's first actual
Gold theft each turn; a first theft against zero Block still spends the allowance.
Its first successful Gold steal doubles only once per combat. Dodge retaliation
chances roll once per Dodge and preparations refresh rather than stack.
Golden Recovery and Stolen Breath finish their healing for a living Fox even when
the qualifying Gold gain or preceding Dodge retaliation defeats the enemy.
Decoy Swap rolls once per Hero-targeted enemy ability. On success Fox Dodges
the entire ability and reacts once. Piercing Starlight lets Pixie's Holy
attacks ignore half enemy Block; enemies do not currently Dodge.

Paralysis rolls once per Poison attack ability, even when Block absorbs all Health
damage. Existing Poison is not required, and ongoing ticks do not activate it.

### Companion Gold and Leech

Haggler adds Gold only to a positive steal by a living Retriever; an empty
steal grants no Gold. Flawless Bounty rolls per Leech restoration
to convert unallocated excess healing on Lizard Scout into Gold, one for one.
The gain cannot restore Health or start another Leech. War Chest grants the living Hero resolved Block
equal to the living Retriever's actual Gold stolen, after theft modifiers;
Block bonuses and pacing do not scale that conversion again. Treasure Hoard cannot
draw after the enemy dies.

### Loyal Companion

Loyal Companion draws from the Companion's deck when the wearer actually
restores the Companion's Health (overhealing alone does not qualify), at most
once per player turn. Claim the allowance before attempting the draw, even if
no card is available. Normal hand limits, buffering, and control restrictions
apply; healing/draw loops are prevented by the once-per-turn claim.

### Forbidden Knowledge

Forbidden Knowledge pays Health (ordinary Health-cost, no hidden nonlethal
floor, cost before drawing) and draws a card from the wearer's deck on the existing
alternate-turn cadence beginning on player turn 1. A defeated owner cannot
continue; unavailable draws still spend the Health cost.

### Purifying Aura

Purifying Aura performs one ordinary random Cleanse per living ally every other
player turn beginning on turn 1, through the shared Cleanse pipeline (normal
Cleanse reactions, reaches Burn and Poison). Living owners only; Cleansed
allies must be living (no revive).

### Toxiphage and Cold Hunger

Toxiphage grants Leech to Poison Critical attack hits through the shared Leech
pipeline. Cold Hunger rolls its typed Leech chance on Freeze damage, including
ongoing damage. Generic and matching typed chances add up to 100%; damage already
granting Leech skips the roll and never Leeches twice.

### Enemy Basic Freeze bonuses

Enemy Basic Freeze bonuses apply once to the initial Basic action, including
the initial pulse of recurring damage, and not to subsequent ongoing damage. This uses
normal Freeze damage and control resolution for both Frost Elemental and Winter Wolf.

## Damage and control

### Poison riders and damage conversions

Venomous Skin resolves its immediate Poison damage before attaching stacks.
Prismatic Edge rolls once per attack action to add either
Freeze or Burn damage, chosen equally and shared across that action's hits.
Each bonus hit copies the actual Health damage dealt, then uses current
elemental defenses without repeating source bonuses, Critical damage or pacing.
Burn stores its own Health damage as ordinary decaying Burn; Freeze adds its normal
control buildup. Fully blocked hits, ongoing damage and reactions cannot proc it.
Counterattacks roll independently; the source and target must survive to resolve
the bonus. The legacy conditional Physical flat-bonus field remains supported.
Sunwall rolls once per Holy ability and, on success, grants the Companion Block
equal to actual Holy Health damage without applying Block bonuses or pacing
again. Holy follow-up damage shares that ability's roll allowance. Committed Holy
Thorns still deals damage after the Knight falls, but cannot earn Sunwall Block.

### Physical damage rewards and Burn ticks

Concussive Force and Martial Guard include Physical reaction and periodic damage,
not only attacks. Their proportional rewards use actual Health damage; converted
Block is already resolved and does not receive outgoing Block bonuses again.
Healing Flames and Flame Shield roll once per Burn ability after positive Health
damage. Ember Shield instead improves its owner's Block absorption against a
Burning attacker. Fully absorbed ticks grant no damage rewards.

### Thick Hide

Thick Hide applies a flat Physical damage reduction only while its owner has Block.

### Concussive Blow and Pulverize

Concussive Blow applies its reduction after the final Stun skip and retains it
through the recovered turn, including every hit of the recovered action.
Pulverize removes enemy Block on Physical Critical Hits from full Basic
counterattacks as well as played cards, including hits fully absorbed by Block.

### Dazing Swipe

Dazing Swipe rolls once per Physical attack ability, using its authored chance
and directly grants Stun build-up without an additional damage hit. Retaliation
and periodic damage do not qualify.

### First Physical attack Critical Hit preparation

The `firstPhysicalAttackGuaranteedCritical` trigger guarantees the wearer's first
qualifying Physical attack each combat Critically Hits; preceding non-Physical
attacks neither Crit nor spend the combat allowance. This is distinct from
Panther's [Surprise Strike](#panther-dodge-preparations), which prepares doubled
damage after its first Dodge.

### Mimic

Mimic deals one additional Bleed damage hit (ordinary Bleed damage and
application) on its first attack only, through the normal damage pipeline;
subsequent hits and ongoing ticks do not repeat the bonus.

### Lead the Hunt

Lead the Hunt applies a percentage bonus to Companion attacks against Bleeding
enemies; it adds no unconditional flat Bleed damage.

### Beastbond

Beastbond restricts its Companion damage bonus to Physical damage (no separate
Physical attack added to non-Physical attacks).

### Noxious Reaction, Serrated Blades, and Blood Money

Noxious Reaction prepares one guaranteed Bleed Critical Hit after a Poison
Critical Hit, retaining the creating action and card so their later hits and
repeats cannot consume it. Serrated Blades extends Bleed applied by a Critical Hit without
creating an extra damage event. Blood Money rewards its owner's lethal hit
against a Bleeding enemy, including lethal Bleed detonations, instead of
rewarding each damage event.

### Bloodfire

Bloodfire applies a percentage bonus to existing Burn attack damage against
Bleeding enemies, checking the target on each hit. It creates no Bleed hit or stack and does not
amplify ongoing Burn. Burn stacks still inherit their attack's actual Health damage.

### Paralysis, Bloodrush, and Arcane Focus

Paralysis uses the Poison-attack cadence described above. Bloodrush rolls once
per Bleed ability that Critically Hits and draws an ordinary card from its owner's
deck. Arcane Focus adds one damage to Mana
empowerment without creating another elemental hit.

### Steam Explosion and Backdraft

Steam Explosion deals its authored Burn damage when its owner Freezes an already
Burning enemy, through the ordinary Burn pipeline. Existing Burn is retained.
Backdraft increases Critical Hit damage against Burning enemies within the
existing hit.

### Phoenix rebirth

From the Ashes restores Health when Phoenix enters Death's Door through the
shared party protection rule. Blazing Rebirth deals its Burn on entry. Afterglow and
Phoenix Vigor fire only if Phoenix survives until Death's Door expires;
Lingering Spirit extends that protection and delays those survival rewards.
Fortified Rebirth and Ashen Ward protect Phoenix only during Death's Door.

## Card preparation and rewards

### Bounty Hunter and winning hits

Bounty Hunter grants Gold only when its owner delivers the critical killing blow;
a partner's critical kill does not qualify. Companion attack rewards retain their
Block, Mana, and draws on winning hits; enemy damage and miss preparations require
a living enemy.

### Quick Fingers

Quick Fingers draws when the owner's Critical Hit and Gold steal occur in the
same ability. Claim the draw once per ability before drawing; ordinary Gold
gains and another party member's theft do not qualify. Normal hand limits,
buffering, and control restrictions apply.
Basic counterattacks retain their own Critical Hit facts and qualify for Quick Fingers;
they cannot borrow the interrupted card's Critical Hit result.

### Card-triggered reactions

A defeated card owner cannot continue firing on-play rewards or reactions.
Typed Critical Hit rewards also recognize full Basic counterattacks. Frost Circuit
restores Mana for each Freeze Critical Hit; Noxious Reaction, Cutpurse Cut, Ashen
Arsenal, and Companion Burn Critical Hit Mana retain their existing reward cadence.
Critical healing, ongoing damage, and non-attack effects do not qualify.
Companion attack rewards such as Bone Shield and Bloodrush also recognize full
Basic counterattacks. Their ability allowances belong to that counterattack,
independently of an interrupted card's allowance.

Supernova recognizes full Basic counterattacks using their own ability allowance.
Bloodfire also strengthens counterattacks and repeated attacks; resolved card
repeats retain captured bonuses without applying them twice. Prismatic Edge rolls
for counterattacks and repeated attacks as independent actions.
Holy Basic counterattacks retain Hallowguard and ordinary Holy damage rewards; Critical Basic counterattacks retain
Light Fingers and ordinary Critical Hit rewards. Raw retaliation and damage repeats
keep their existing reaction guards.

Bloodkindling also readies its Bleed bonus after a Burn Basic counterattack.
Toxic Transfusion requires the Companion to survive the Critical Hit's retaliation
before preparing the Hero's doubled Poison attack. Sealed Vial and Unstable Culture
also amplify full Basic counterattacks; the counterattack consumes the corresponding
first-attack allowance or readied preparation before a later Poison card.
Blind Spot also applies to the next full Physical Basic counterattack, consuming
its Block bypass for that action before a later Physical card.

Cracked Guard prepares the source's next attack after Physical damage breaks enemy
Block, including reactive damage. The creating card or action cannot spend that
preparation. Confounding Loot requires the enemy to be Stunned when the hit lands;
the hit that first Stuns it does not qualify. Its Gold is theft, so Golden Opportunity,
Master Thief, and other theft reactions apply.

### Next-card preparations

Next-card preparations are captured before a card resolves, refresh instead
of accumulating, and cannot be consumed by the card that created them, even
when it repeats. Typed damage bonuses strengthen an existing unconditional hit
of that type when present, avoiding duplicate equipment bonuses. Sniff Out's
recipient-owned preparation follows the [ability strategy contract](battle-actions.md#ability-strategy).
Predator's
Focus deals Bleed damage and prepares the caster's next attack with Leech.
Gilded Claws
instead accumulates actual Gold stolen until the next attack. Authored
`Ability.stealsGold` identifies theft from Steal, Bounty Shot, Blackjack,
and Tithe; the marker survives outcome resolution and empowerment.

Volatile Remedy likewise reserves its Poison bonus for a later ability;
Leech restoration during a multi-hit Poison attack cannot strengthen its later hits.
Sanguine Overflow and Sated Fury retain the action and card that restored full
Health; a multi-hit attack cannot spend that readiness on its own later hit. Bounty
Blade, Primal Rage, Bone Burst, and Bloodkindling likewise reserve their typed
damage beyond the creating action and card, including supported card repeats.

Aftershock Guard, Winter's Wake, Redline, Ashen Vitality, Golden Guard,
Revealed Flaw, and Sanctified Scroll also reserve their next Block gain,
typed attack, or Critical Hit bonus for a later ability. Multi-hit creating
abilities cannot spend them.
Ashen Vitality, Sanctified Scroll, and Aftershock Guard also retain their creating
action so counterattacks without a card frame cannot spend the fresh bonus.
Heat Recovery records the Cleanse action and card that readied its Burn bonus,
including when refreshing an existing preparation. Paid in Full likewise reserves
its damage for a later ability, including theft from Saintfall and Golden Verdict
reactions between hits of the current card.

### Reaction attack preparations

Whiplash, Wing Buffet, and Counter Pounce prepare damage for the wearer's next
Stun, Freeze, and Bleed attack respectively after Dodge. Arm them after the Dodge's
counteractions finish, even when counterattacks are disabled; a fallen owner cannot
arm a bonus. Denouncing prepares Holy attack damage only after an actual enemy
buff removal. Empty Purges leave existing readiness unchanged.
Toxic Touch prepares Poison attack damage after its Companion's Leech Critical
Hit, including guaranteed Leech attacks at full Health. It creates no Poison hit
or stack and combines independently with Volatile Remedy and Toxic Remedy.
Each preparation replaces its own amount and creating action/card provenance;
it does not accumulate. The creating action/card, ongoing damage, other damage
types, and other actors cannot spend it. The next later matching attack consumes
it on one hit, folding its amount into that hit. Existing resolved card-repeat
snapshots do not consume or apply the bonus again. Prepared amounts remain in the
combatant's status summary.

### Panther Dodge preparations

Surprise Strike doubles the next attack after Panther's first Dodge each
combat. Stalker's Precision ignores Block and Vanish guarantees a Critical
Hit on the next attack. Counter Pounce prepares damage for the next Bleed
attack after Dodge; Regroup rolls for one card draw. Preparations refresh instead
of stacking.

Lizard Scout's Cold Blood returns Poison on every Dodge; Barbed Tail rolls
once per Dodge for Bleed damage, limiting simultaneous typed
retaliation feedback.

### Sleight of Coin and Jackpot

Sleight of Coin prepares an additive Dodge chance bonus for the rest of the turn after a successful
Gold steal; repeated steals refresh rather than stack it. Jackpot folds its
extra Gold into a Critical Hit's Gold steal, producing one Gold gain event.
This also applies to a qualifying Basic counterattack's own Critical Hit and theft.

### Consolation Prize and Feigned Miss

Consolation Prize adds one uniformly random player ability to its owner's hand
on the first fully Blocked attack each combat. The new physical copy remains in
that owner's deck for the battle; no Gold is granted. Feigned Miss still prepares
double damage for the next Physical attack after an attack is fully Blocked.
Neither reward requires Health damage, and the creating card cannot consume the
prepared attack bonus.
Full Basic counterattacks also qualify for Consolation Prize and Feigned Miss;
their next-attack preparation retains the creating action's identity.

### Clear Mind and Smite the Wicked

Clear Mind draws once per successful Cleanse operation while its source has zero
Mana at removal, before healing or Mana reactions. Self and ally removals qualify;
empty Cleanse does not. It grants no empowerment discount. Smite the Wicked draws
once per successful enemy Purge operation while its living source is below half
Health, replacing Holy damage preparation. Removing several effects in one
operation still draws once; separate successful operations have no turn limit.

## Mana and empowerment

Overcharge and Soul Burn prepare bonuses for a later attack. Their preparing
ability cannot consume the bonus, even when it has multiple hits or is a
Mana-empowered counterattack without a card frame.
Arcane Surge likewise draws for last-Mana spending during a counterattack Basic,
with one draw allowance per ability.

### Dark Recovery and Arcane Burst

Dark Recovery increases Leech healing while the owner has no Mana. Arcane
Burst rolls once per Mana-empowered ability and applies its damage multiplier
within that action. Wolf's Phantom Counter prepares a multiplier for its next
Physical attack after Dodging; repeated Dodges refresh rather than stack it.

### Mana Cocoon, Arcane Cleansing, and Chaos Rift

Mana Cocoon improves its owner's Block absorption while it has unspent Mana.
Arcane Cleansing performs an ordinary
Cleanse when its owner ends a turn at zero Mana. Chaos Rift increases damage
from Mana-empowered Critical Hits within the existing hit.

### Dragon’s Patronage and Prismatic Scales

Arcane Breath adds damage to existing Freeze operations during Mana
empowerment; a Burn outcome of Astral Arrow gains no extra Freeze hit or buildup.
Dragon’s Patronage grants Block to Frost Whelp's ally once per Mana-empowered
ability. Mana Moth's Prismatic Scales strengthens existing Burn and Freeze
damage during Mana empowerment, without adding hits or another Mana payment.

## Healing and overflow

### Soul Drain and healer-provided Block

Soul Drain, Barrier Blessing and Reclaimed Reagents follow the canonical
[overflow allocation and conversion order](battle-healing.md#allocation-and-overflow).
The named targeting and preparation exceptions below remain separate.

### Campfire Comfort

Campfire Comfort restores Health to the lowest-Health living ally at the end
of every other player turn, beginning on turn 1. It skips a fully healed ally.

### Sacrificial Guard and Man's Best Friend

Sacrificial Guard lets Golden Retriever's Block absorb incoming damage to its
Hero ally before the Hero's own Block. Man's Best Friend redirects the first
non-Health-cost fatal damage to the living Retriever once per combat, after
all Block absorption and only when Death's Door cannot protect the Hero. The
redirected damage uses the ordinary damage pipeline;
the intercept is marked as spent before that resolution starts.

### Elemental Leech

Carnivore reserves its first Bleed attack's Leech before rolling Critical chance,
so that attack can receive Taste for Blood. Dodges and zero-damage requests do
not spend the allowance; it refreshes each turn.

Typed damage Leech uses the standard Leech rate and never adds a second base
contribution to an already-Leeching hit. Symbiotic Venom grants Leech only to
Poison attacks, excluding ticks and reaction damage. Overhealing keeps its emitted
reactions even when no Health is restored.

Emberdrinker reserves Leech for its owner's first Burn attack action each turn
only if the owner starts that action strictly below half Health. The first Burn
action spends the allowance even above that threshold. All Burn components of
the qualifying action retain Leech if healing crosses half Health. Later actions,
card repeats, ticks, and detonations do not reuse the allowance. The separate
`burnDamageLeech` rule still includes ongoing Burn damage.

### Shared Leech

Symbiosis, Shared Feast and Soul Sharing use the canonical
[Leech sharing contract](battle-healing.md#leech-and-shared-restoration).

### Living Archive, Wishspring, and Marrowmend

Living Archive rolls once per Health-restoring ability and gives Thorns to
one healed ally on success. Wishspring uses the original overhealing amount
alongside existing Block and maximum-Health conversions. Marrowmend converts
half the first excess Leech restoration each turn into resolved Block; later
turns can add to existing Block.

### Shelter Seed, Shared Prescription, and Thorn Shedding

Shelter Seed checks Health before healing and grants Block only after
actual restoration. Shared Prescription offers excess healing to the other
living ally up to their missing Health without applying healing bonuses again,
then Reclaimed Reagents can convert
half the remainder to Block. Thorn Shedding adds Poison damage after its
owner's first positive Thorns Health damage each turn, with normal Poison
application. It leaves Physical and other Thorns conversions intact; other
allies cannot use the owner's allowance.

### Cleansing Dew

Cleansing Dew removes Poison and Bleed from the healed recipient after actual
Health restoration. Both statuses belong to one Cleanse operation, so combined
removal does not multiply per-operation reactions. Other debuffs remain unless
another Cleanse talent explicitly removes them. Shared Roots still requires the
healer to survive the Cleanse reactions.

### Library Owl restoration and Cleanse

Owl's Aether Shield and Living Archive each roll once per restoring ability
after actual Health is gained. A successful roll affects one healed ally:
Aether Shield grants Block equal to their restoration; Living Archive grants
Thorns. Font of Magic rolls once when an ability restores Health or Mana,
even when it restores both. Purifying Light's automatic Cleanse uses normal
Cleanse reactions when it succeeds; it rolls once per Holy ability.

## Removal, protection, and Block

### Guardian

Guardian grants the Hero Block before the first qualifying Hero-targeted
attack each combat. Ongoing damage and Dodged attacks do not consume it.

### Warning Bark

While the Retriever is alive, Warning Bark adds 20 percentage points of Dodge
chance to each ally with positive Block. Check the target's current Block when
resolving Dodge; use the normal Dodge cap and feedback, with no recurring event.

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
Adamant Carapace increases its owner's Block absorption for all damage
types through the ordinary absorption calculation. The numeric absorption trigger
uses a neutral multiplier of one; the legacy doubling field remains readable for
retained serialized powers.

### Stolen Thunder

Stolen Thunder prepares the owner's next attack to Critically Hit after it Stuns
the enemy. The creating action cannot consume that preparation; refreshes do not
stack.

### Resonant Shell

Resonant Shell increases Stun attack damage while its owner has Thorns. Recurring
Stun damage and reaction damage do not receive this attack bonus.

### Interdict, Blinding Light, and Subzero Mist

Interdict prevents new enemy Block after a Holy attack Critical Hit until the
next party turn. Existing Block remains; no Purge is required and other buffs,
healing, and resources remain available. Legacy `interdict` profiles retain their
distinct purged-buff protection contract.
Steadfast and Perfect Purity also stop control-multiplication effects from
increasing existing Freeze build-up while their protection applies.
Blinding Light prepares the authored miss chance for the enemy's next attack
after a Holy attack hit. Consume it once for that enemy ability. Subzero Mist
rolls its authored extension chance when its owner triggers Freeze, extending
control through the ordinary action-skip lifecycle.

### Mana Absorption

Mana Absorption converts excess Mana restored into resolved Block, including at
full Mana. Only overflow funds the grant; actually restored Mana remains separate.
The conversion and pending Block accumulation saturate at integer capacity.
The existing enable flag remains serialized, with a separate per-Mana amount
defaulting to 1 for older profiles. Merging uses the strongest conversion amount.

## Distinct engine triggers

These supported fields are separate from the current talents above. Keep their
contracts when handling stored profiles or explicit engine fixtures; fallback
event names do not establish which trigger an authored talent grants.

| Trigger | Contract |
|---|---|
| `gainGoldDrawThreshold` | Draw on the first Gold grant meeting the threshold each player-turn cycle. |
| `poisonThresholdStunAmount` / `poisonStunChancePercent` | After Poison Health damage, including ticks, check existing Poison potency and roll for Stun. |
| `steamExplosion` | Consume Burn during Freeze-card preparation and add its potency to that card's Freeze damage. |
| `spendManaGrantsEqualBlock` | Grant Block from each actual Mana payment. |
| `spendManaThresholdAutoPlayCard` | Retain excess Mana-spend progress across cards and turns; automatic plays cannot recursively advance it. |
| `phantomCounter` | Dodge draws and automatically plays a Physical card; retain automatic ancestry through nested payments and card reactions. |
| `onAllyBurnDamageGainBlock` | Grant Companion Block after its ally's damaging Burn, including ticks. |
| `lightFingered` | Combat Gold gains steal up to that amount of enemy Block. |
| `sealedSarcophagus` | Protect Block from theft and Purge; damage, decay, and voluntary spending remain available. |
| `stolenThunder` | Spend the attacker's Block once per Stun attack and add it to damage. |
| `blindingLight` | Retain the strongest reduction equal to half the sum of Holy Health damage and absorbed Block for the next enemy attack, including its multiple hits; ongoing damage does not consume it. |
| `subzeroMist` | Grant Dodge after enemy Freeze recovery until the next party turn. |

## Storage ownership

Battle-local talent state, action/card reservations, and preparation provenance
follow the [actions and cards contract](battle-actions.md). Saved talent selections
remain roster-owned under [persistence storage](persistence-storage.md).

Trigger and per-combatant talent storage retain value semantics through copy-on-write. Read accessors
borrow stored fields instead of copying the complete trigger set onto the stack;
this matters when attacks resolve nested companion actions.

Operation contracts: [damage](battle-damage.md), [actions](battle-actions.md), [healing](battle-healing.md).
