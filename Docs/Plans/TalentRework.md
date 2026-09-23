---
type: execution-plan
status: active
created: 2026-09-23
updated: 2026-09-23
expires: 2026-10-07
---

# Talent redesign

## Objective

Revise all 446 Talent nodes across 21 combatants and 63 keyword trees, then make
their actual mechanics match the approved text. The eight Heroes have now been
reviewed; implement their approved revisions first. Review the 13 Companions in
a later pass. Keep each tree's current node count. The user confirms there are
no players or saves to migrate, so IDs may change when a tree move requires it.

## Agreed design constraints

- Every Talent description must mention its tree's keyword or an inflection of
  it. Match the owner's one-Basic, one-Skill, one-Ultimate loadout pool; a Talent
  may reward a compatible owner loadout. Prefer partner-independent effects;
  Druid's approved Grove Accord intentionally rewards a Mana-using Companion.
- Follow Alchemy's concise, direct rules voice without periods. Use **ability**
  for play/equip references only when needed, but say **draw a card** or **draws
  a card** for draws, never “draw 1 card” or “draws 1 card”;
  prefer damage, attack, or keyword wording when clearer.
  Usually avoid naming Basic, Skill, or Ultimate tiers in Talent rules. Prefer
  “Enemies below half Health take…” to clipped threshold phrasing, and use
  “is increased by” rather than “rises” for damage changes. Avoid “tick” in
  player-facing text; name ongoing damage or simplify the effect. Say **steal**
  rather than “theft,” and **Stun build-up** or **Freeze build-up** for control
  meters. Name the specific defense or damage type instead of generic “enemy
  damage reduction.”
  Do not use “buff” or “debuff”; use “positive status effect” or “negative status
  effect.” Avoid combatant names in descriptions.
- Give each Talent one clear trigger and payoff. Simplify the mechanic when its
  full rule cannot be explained clearly in roughly 12 words. Connect the trigger
  and payoff to the Talent name, combatant, and tree keyword.
- Avoid per-hit and per-tick side effects, crowded simultaneous floating combat
  feedback, and large multipliers under easily sustained conditions. A rare
  ability payoff may add one extra chip. Chance effects roll once per ability.
  Keep row power equivalent; scale payoffs to trigger difficulty. Avoid arbitrary
  caps.
- Avoid arbitrary DoT stack-count thresholds, easily repeated stack doubling,
  and effects that consume a status for a payoff worth less than leaving it in
  place. Direct and periodic Burn, Poison, and Bleed damage use ordinary Block
  absorption unless a specific bypass rule applies; word Block interactions
  around that actual behavior. Avoid “at X Gold” gates and card draws on every
  Gold steal; use distinct, thematic triggers instead. The user explicitly kept
  Rogue's current Light Fingers, Coinmail, and Contagion as exceptions.
- Battles start at full Health and Mana and currently have one enemy. Healing,
  Mana, Block, and draws awarded only after a kill or after combat have no useful
  combat window; persistent Gold rewards can remain. Keep at most one kill-only
  reward per tree.

## Review and implementation

- [x] Inventory authored Talents and compare Alchemy's wording and Trinket's
  Ability pool, keyword rules, battle mechanics, and feedback presentation.
  The current manifest has 29 descriptions that omit their own tree keyword;
  review those even if the user prefers their current design.
- [x] Resolve the four Knight keyword-placement entries below; all Hero Talent
  effects and wording are approved.
- [x] Review the eight Heroes in current/proposed batches and record the user's
  choices, subject to the remaining Knight and numeric decisions below.
- [ ] Review Companions in a later pass; leave their existing behavior intact
  during the Hero implementation.
- [ ] Audit every selected effect for tree-keyword wording, viable owner loadout,
  thematic fit, simple mechanics, unique name and icon fit, and feedback density
  when all tree nodes are unlocked together. Strengthen catalog coverage to
  require each Talent's own tree keyword, rather than any keyword, in its text.
- [x] Implement the approved Hero catalog in `ContentManifest/talents.tsv`, the
  relevant trigger schemas and battle owners, then regenerate catalogs. Update
  canonical behavior guidance and meaningful deterministic coverage. Defer
  Companion Talent redesign and implementation.
- [ ] Run routed, isolated handoff for all changed paths; review generated
  consistency and the final diff. Archive the plan outcome and delete this file
  when the whole redesign is complete.

### Hero implementation ledger

- [x] Apply approved Hero names and descriptions to the authored manifest;
  update existing Companion draw-one wording without changing Companion rules.
- [x] Wire all eight Hero trigger trees to their approved effects; the
  BattleEngine package builds and the generated catalog is stable.
- [x] Bloodfire rolls once per Burn ability; success deals 4 Bleed damage.
- [x] Consolation Prize rewards the first fully Blocked attack each combat;
  Feigned Miss prepares double damage for a later Physical attack.
- [x] Overcharge and Soul Burn bonuses wait for a later attack, excluding the
  ability that prepared them.
- [x] Masterwork Mixture restores Mana to the Alchemist; Shared Prescription
  transfers excess Health restoration in either direction.
- [x] Audit the Hero catalog against the approved plan and trigger owners:
  all 169 Hero descriptions match, keyword inflections are present, obsolete
  Bloodfire, Consolation Prize, and Feigned Miss paths are removed, and the
  generated catalog is stable. Canonical Talent behavior notes are updated.
- [x] Replace tests for retired Hero effects with deterministic coverage of
  current rules, preserve Companion checks, and add catalog-wide Hero keyword
  coverage. Remove unused pre-rework trigger schema fields.
- [x] Review follow-up fixes Divine Blessing's revive allowance, overlapping
  Block bypasses, excess healing transfer, and feedback for automatic Talent
  damage. The Hero phase passes routed, isolated handoff.
- [ ] Defer Companion Talent redesign and its mechanics until the later pass.

## Knight · Stun — approved

| Talent | Approved description |
| --- | --- |
| Heavy Flail | Deal 3 additional damage to Stunned enemies |
| Concussive Blow | Stunned enemies deal half damage when they recover |
| Skullcracker | Stun Critical Hits deal double damage |
| Second Wind | When Stun ends, draw a card |
| Searing Bind | Stun lasts 1 extra turn on Burning enemies |
| Crusader's Mark | Holy damage is increased by 5 against Stunned enemies |
| Lightning Rod | Stun damage is increased by half your Block |

## Knight · Block — approved

| Talent | Description | Status |
| --- | --- | --- |
| Bastion Stance | Start combat with 6 Block | Approved |
| Spiked Barricade | Thorns damage is doubled while you have Block | Approved |
| Intercede | Your Block also absorbs damage dealt to your Companion | Approved |
| Guarded Impact (was Shield Bash) | Physical damage is increased by 25% of your Block | Approved |
| Consecration (moved from Holy) | With Block, take half Burn, Poison, and Bleed damage | Approved Block-tree placement |
| Unbreakable | Keep 75% of your Block between turns | Approved |
| Stalwart Oath | Below half Health, Block absorbs 50% more damage | Approved |

## Knight · Holy — approved

| Talent | Description | Status |
| --- | --- | --- |
| Oathbound | Holy damage is increased by 25% while you have Block | Approved |
| Pure Radiance | Holy damage is increased by 50% against enemy Block | Approved |
| Holy Infusion | Your Thorns deal Holy instead of Physical damage | Approved |
| Shield Shatter (moved from Block) | Holy attacks ignore half enemy Block | Approved Holy-tree placement and wording |
| Smite the Wicked | Purging an enemy doubles your next Holy attack | Approved |
| Divine Blessing | Holy damage has a 10% chance to revive your Companion | User revision; revives at 1 Health; roll only if Companion defeated |
| Sunwall | Holy damage has a 10% chance to grant equal Block to your Companion | User revision; Block equals actual Holy Health damage dealt |

### Knight keyword correction — approved

Keep seven nodes in each tree by moving Consecration into Block row 3 and Shield
Shatter into Holy row 2. Consecration keeps its approved effect. Shield Shatter
changes from Physical to Holy. Chance riders on Divine Blessing and Sunwall
roll once per qualifying Holy ability, not separately for each component.

## Ranger · Poison — approved

| Talent | Description | Status |
| --- | --- | --- |
| Venomous Arrows | Poison attacks deal 2 additional damage to Bleeding enemies | Approved |
| Paralytic Poison | Poisoned enemies have 15% less accuracy | Approved |
| Prey on the Weak | Companion attacks deal 25% more damage to Poisoned enemies | Approved |
| Toxic Backlash | Poison deals double damage once after a Poisoned enemy hurts your Companion | Approved; one future damage result, no stack multiplication |
| Corrosive Venom | Poison attacks remove 2 extra Block | Approved |
| Lethal Dose | Enemies below half Health take 25% increased Poison damage | Approved |
| Toxic Transfusion | Companion Critical Hits double your next Poison attack | Approved; one prepared attack, refresh rather than stack |

## Ranger · Bleed — approved

| Talent | Description | Status |
| --- | --- | --- |
| Lead the Hunt | Companion attacks deal 25% more damage to Bleeding enemies | Approved |
| Broadhead Arrows | Bleed attacks ignore half enemy Block | Approved |
| Hamstring Shot | Bleeding enemies deal 25% less damage | Approved |
| Bloodscent | Bleed lasts 1 extra turn | Approved |
| Pinning Strike | Bleed attacks deal 50% more damage to Stunned enemies | Approved |
| Blood Tracker | Gain +15% Critical Hit chance against Bleeding enemies | Approved current effect |
| Shatterpoint | Stunning a Bleeding enemy doubles its next Bleed damage | Approved; one future damage result |

## Ranger · Burn — approved

| Talent | Approved description |
| --- | --- |
| Flaming Arrows | Burn attacks deal 50% more damage to enemy Block |
| Slow Burn | Burn fades 30% slower on Bleeding enemies |
| Woundfire (was Cauterize) | Bleeding enemies take 25% increased Burn damage |
| Smoke Screen | Burning enemies grant both allies +10% Dodge |
| Scorched Earth | Burning enemies gain 25% less Block |
| Inferno Barrage | Burn Critical Hits deal 4 additional damage |
| Firebrand | Companion attacks gain +15% Critical chance against Burning enemies |

## Rogue · Gold — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Light Fingers | Gain 2 Gold when you Critically Hit. | Keep current exactly |
| Coinmail | Whenever you gain Gold in combat, gain Block equal to half that amount. | Keep current exactly |
| Cutpurse Cut | Stun Critical Hits steal 5 Gold | Accept proposal |
| Escape Fund (was Gold Reserves) | After Dodging, double the next Gold you steal | Accept proposal |
| Bounty Hunter | Defeating an enemy with a Critical Hit grants 10 Gold | Accept proposal |
| Quick Fingers | Critical Hits that steal Gold draw a card | Accept proposal |
| Bounty Blade | Stealing Gold adds 3 damage to your next Physical attack | Accept proposal |

## Rogue · Poison — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Toxic Coating | Bleeding enemies take 25% increased Poison damage | Accept proposal |
| Lingering Toxin | Poison fades 25% slower | Accept proposal |
| Noxious Reaction | Poison Critical Hits make your next Bleed attack Critically Hit | Accept proposal; preparation refreshes rather than stacks |
| Blinding Fumes | Poisoned enemies deal 20% less damage | Accept proposal |
| Contagion | Poison damage has a 25% chance to grow instead of fading. | Keep current exactly |
| Deadly Dose | Poisoned enemies take 25% additional damage | Accept proposal |
| Nerve Agent | Poisoned enemies take 25% more Stun build-up | Accept proposal |

## Rogue · Bleed — approved

| Talent | Final description |
| --- | --- |
| Serrated Blades | Bleed from Critical Hits lasts 1 extra turn |
| Deep Wounds | Bleed ignores enemy Block |
| Taste for Blood | Leech attacks gain +25% Critical chance against Bleeding enemies |
| Blood Money | Defeating Bleeding enemies grants 5 Gold |
| Exsanguinate | Bleed Critical Hits deal double damage below half enemy Health |
| Mortal Wound (was Scent of Blood) | Bleeding enemies restore half as much Health |
| Septic Wound (was Cryostasis) | Bleed lasts 1 extra turn on Poisoned enemies |

## Wizard · Freeze — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Persistent Frost | Deal 2 additional Freeze damage to Frozen enemies | Accept proposal |
| Numbing Cold | Freeze has a 20% chance to last 1 extra turn | Accept proposal |
| Thermal Shock | Frozen enemies take 50% increased Burn damage | Accept proposal |
| Glacial Barrier | Gain 3 Block whenever an enemy becomes Frozen. | Keep current exactly |
| Deep Freeze | Frozen enemies cannot gain Block or restore Health | Accept proposal |
| Whiteout (was Blizzard) | Increase Freeze build-up by 20% | User revision |
| Glacial Reprieve | Damage you Block is returned as Freeze | Keep current mechanic; user wording |

## Wizard · Burn — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Ignition | Burn deals 25% more damage to enemies with no Block. | Keep current exactly |
| Smoldering (was Wildfire Spread) | Burn fades 25% slower | Accept proposal |
| Searing Heat | Burn ignores enemy Block | Accept proposal |
| Fuel the Flames | Mana-empowered Burn attacks deal 1 additional damage | User magnitude revision |
| Supernova | Burn attacks have a 10% chance to deal double damage | Accept proposal |
| Pyromancer's Spark | Empowering Burn attacks costs 1 less Mana | Accept proposal |
| Backdraft | Burning enemies take 25% increased Critical Hit damage | Accept proposal |

## Wizard · Mana — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Arcane Focus | Mana empowerment increases attack damage by 1 | User magnitude revision |
| Mana Shield | At the end of your turn, gain 1 Block for each unspent Mana. | Keep current exactly |
| Overcharge | Mana empowerment increases your next attack's damage by 20% | User magnitude revision |
| Arcane Cleansing | Ending a turn at 0 Mana Cleanses 1 negative status effect | Accept proposal |
| Arcane Surge | Spending your last Mana draws a card | Accept proposal |
| Spell Echo | Mana-empowered attacks have a 10% chance to deal double damage | Accept proposal |
| Frost Circuit (was Closed Circuit) | Freeze Critical Hits restore 1 Mana | User revision |

## Warlock · Leech — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Vampiric Touch | Leech also heals from damage absorbed by enemy Block. | Keep current exactly |
| Armor Pierce | Leech attacks ignore half enemy Block | Accept proposal |
| Blood Link | Excess Health restored from Leech is transferred to your Companion. | Keep current exactly |
| Soul Drain | Leeching Health restores 1 Mana. | Keep current exactly |
| Sanguine Overflow | Leeching to full Health adds 1 bonus damage to your next attack | User magnitude revision; trigger only when Health rises from below full |
| Soul Ward | Leech also grants Block when below half Health | User wording; Block equals Health actually restored |
| Emberdrinker | Burn damage gains Leech | Keep current mechanic; user wording |

## Warlock · Mana — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Dark Recovery | At 0 Mana, Leech restores 50% more Health | Accept proposal |
| Forbidden Lore | Gain 1 Mana when you lose Health | User revision; Health loss includes self costs, attacks, and status damage |
| Eldritch Shield | Spending Mana grants 2 Block. | Keep current exactly |
| Hexing Rune | Mana empowerment Purges 1 positive status effect | Accept proposal |
| Chaos Rift | Mana-empowered Critical Hits deal 50% more damage | Accept proposal |
| Life Tap | Health costs reduce your next Mana empowerment cost by 1 | Accept proposal |
| Void Focus (was Eye of the Storm) | At 0 Mana, Burn damage is increased by 25% | Accept proposal |

## Warlock · Burn — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Bloodfire | Burn attacks have a 10% chance to deal 4 Bleed damage | User final amount and once-per-ability roll |
| Scorching Ash | Below half Health, Burn damage is increased by 25% | Accept proposal |
| Withering Flame | Burning enemies restore half as much Health | Accept proposal |
| Soul Burn | Spending your last Mana increases your next Burn attack’s damage by 50% | Accept proposal |
| Damnation | Burning enemies take 25% additional damage | Accept proposal |
| Raging Inferno | Gain +15% Critical Hit chance against Burning enemies | User revision |
| Ashen Arsenal | Burn attacks that Critically Hit draw a card | Accept proposal |
| Temper Cycle | Burn attacks add 1 bonus damage to your next Bleed attack | User magnitude revision |

## Alchemist · Poison — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Reactive Coating | Poison Critical Hits deal 2 additional damage | Accept proposal |
| Safe Handling | Poison attacks ignore enemy Thorns | Accept proposal |
| Reactive Sediment | Burning enemies take 25% increased Poison damage | Accept proposal |
| Spent Reagents | Poison fading completely restores 2 Mana | Accept proposal |
| Dissolving Fumes | Poison deals 50% more damage to enemy Block | Accept proposal |
| Unstable Culture | When Poison fades, your next Poison attack deals double damage | Accept proposal |
| Sealed Vial | Your first Poison attack each combat deals double damage | Accept proposal |

## Alchemist · Cleanse — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Clear Solution | Abilities that restore Health also Cleanse 1 negative status effect | Accept proposal; Cleanse the healing target even at full Health |
| Fresh Batch | Cleansing a negative status effect restores 2 Health | Accept proposal |
| Heat Recovery | Cleansing Burn adds 2 damage to your next Burn attack | Accept proposal |
| Antitoxin Coating | Cleansing Poison prevents Poison for 1 turn | Accept proposal |
| Clear Mind | Cleansing an ally reduces your next Mana empowerment cost by 1 | Accept proposal |
| Clean Break | Cleansing an ally’s last negative status effect draws a card | Accept proposal |
| Perfect Purity | Cleanse grants its target 1 turn of negative status immunity | Accept proposal |

## Alchemist · Health — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Fortifying Tonic | Allies below half Health restore 2 additional Health | Accept proposal |
| Lifeline (was Measured Dose) | Restoring Health has a 10% chance to draw a card | User rename and effect; roll once per restoration ability |
| Cooling Salve | Restoring Health also Cleanses Burn | User wording and requested mechanic; coordinate with Clear Solution to avoid duplicate Burn removal |
| Reclaimed Reagents | Half of excess Health restoration becomes Block | Accept proposal |
| Shared Prescription | Excess Health restoration heals your ally | User wording and effect |
| Volatile Remedy (was Restorative Fumes) | Restoring Health adds 2 damage to your next Poison attack | Accept proposal |
| Masterwork Mixture | Restoring Health has a 10% chance to also restore Mana | User wording and effect; roll once per restoration ability |

## Druid · Health — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Spring Sap | Allies with Thorns restore 2 additional Health | Accept proposal |
| Pruning Touch | Restoring Health removes 2 enemy Thorns | Accept proposal |
| Quiet Grove | Allies at full Health gain +10% Dodge | Accept proposal |
| Shelter Seed | Restoring Health to allies below half Health grants 3 Block | Accept proposal |
| Cleansing Dew | Restoring Health also Cleanses Poison | Accept proposal |
| Shared Roots | Healing your Companion also restores half as much of your Health | Accept proposal |
| Verdant Shelter | Allies with Thorns take 25% less damage above half Health | Accept proposal |

## Druid · Poison — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Barbed Spores | Poisoned enemies take 25% increased Thorns damage | Accept proposal |
| Living Bark | Take half Poison damage while you have Thorns | Accept proposal |
| Cool Moss | Poisoned enemies take 1 additional Freeze damage | Accept proposal |
| Returning Bloom | Poison fading completely restores 3 Health to your Companion | Accept proposal |
| Root Passage | Poison attacks ignore enemy Block | Accept proposal |
| Entangling Growth | Poisoned enemies take 25% more Stun build-up | Accept proposal |
| Thorn Shedding | Allied Thorns deal Poison instead of Physical damage | Accept proposal; covers both allies, replacing existing damage rather than adding a hit |

## Druid · Mana — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Arcane Thorns (was First Bloom) | Restoring Mana grants 2 Thorns | User name and effect |
| Barkweave | Mana empowerment grants 2 Block | User effect |
| Grove Reserve | With unspent Mana, your Companion gains +10% Dodge | Accept proposal |
| Living Conduit | Excess Mana restored is converted into Thorns | User revision; excess converts without a Companion Mana requirement |
| Shared Current | Mana empowerment adds 2 damage to your Companion’s next attack | Accept proposal |
| Deep Roots | Restore 1 additional Mana while you have Thorns | Accept proposal |
| Grove Accord | Both allies spending Mana in the same turn grants each 1 Thorns. | Keep current exactly; requires a Mana-using Companion |

## Wildcard · Gold — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Consolation Prize | Gain 3 Gold the first time an enemy fully Blocks your attack | User approved blocked-attack replacement |
| Health is Wealth (was House Credit) | Gaining Gold has a 10% chance to restore 3 Health | User wording and amount |
| Jackpot (was Full House) | Critical Hits that steal Gold grant 5 additional Gold | Accept proposal |
| Lucky Charm | Gaining Gold has a 20% chance to Cleanse 1 negative status effect | Accept proposal |
| Last Wager | Gaining Gold while below half Health draws a card | User effect |
| Sleight of Coin | Stealing Gold grants +15% Dodge until your next turn | Accept proposal |
| Lucky Break | Gaining Gold has a 10% chance to draw a card | User effect |

## Wildcard · Dodge — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| False Opening | Dodging grants +20% Critical Hit chance on your next attack | Accept proposal |
| Missed Opportunity | Dodging below half Health draws a card | Accept proposal |
| Passing Luck | Dodging makes your Companion’s next attack Critically Hit | Accept proposal |
| Scattered Caltrops | Dodging has a 20% chance to deal 3 Bleed damage | User chance revision; one roll per Dodge |
| Smoke Trick | Dodging has a 20% chance to deal 3 Burn damage | User chance revision; one roll per Dodge |
| Improving Odds | Each undodged attack increases your Dodge chance by 5%. Dodging resets this bonus. | Keep current exactly |
| Blind Spot | Dodging makes your next Physical attack ignore enemy Block | Accept proposal |

## Wildcard · Physical — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Prismatic Edge | Physical attacks have a 10% chance to deal 3 Burn or Freeze damage | User wording and amount; one roll per ability |
| Standard Deviation (was Improvised Assault) | Physical damage you deal is either doubled or halved | User name and effect; 50/50 once per ability, halved result rounds up |
| Clean Cut | Physical Critical Hits ignore enemy Block | User effect |
| Cracked Guard | Breaking enemy Block with Physical damage makes your next attack Critically Hit | Accept proposal |
| Cold Read | Physical attacks against Frozen enemies gain +15% Critical Hit chance | Accept proposal |
| Feigned Miss | An enemy fully Blocking your attack doubles your next Physical attack | User approved blocked-attack replacement |
| Paid in Full | Stealing Gold adds 2 damage to your next Physical attack | Accept proposal |

## Other combatants

Earlier conversational drafts for the remaining combatants are unapproved.
Record only the user's selected current, proposed, or modified effect here as
each combatant is reviewed. Audit all of them for the tree-keyword rule and
player-facing wording before presenting a batch.
