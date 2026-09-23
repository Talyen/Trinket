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
their actual mechanics match the approved text. All eight Heroes and the first
seven Companions have been reviewed and implemented; the remaining six
Companions await design. Keep each tree's current node count. The user confirms there are
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

### First Companion implementation batch

Implement all 149 nodes for Bear, Frost Whelp, Lizard Scout, Panther, Phoenix,
Golden Retriever, and Library Owl before designing the remaining six
Companions. Keep their node counts and approved tree placement. Leave Wolf,
Risen Skeleton, Mana Moth, Pixie, Shield Scarab, and Fox behavior unchanged.

- [ ] Resolve the explicitly pending interaction choices below. Continue
  independent approved work while waiting for an answer.
- [x] Apply approved names, descriptions, and trigger values to the authored
  Talent manifest; remove replaced triggers from the authored schemas and
  regenerate the catalog through `Scripts/generate.sh`.
- [x] Wire damage, control, Block, Dodge, resource, healing, Death's Door, and
  preparation effects in their owning BattleEngine pipelines. Chance riders
  roll once per ability unless the approved text specifies a turn decay roll.
  Prepared next-attack/restoration bonuses cannot be consumed by their
  creating ability; refresh rather than stack unless explicitly specified.
- [x] Keep triggered damage and restoration in ordinary combat pipelines while
  preventing recursive Talent chains. Coalesce same-action Bleed detonation
  feedback, make Barbed Tail's Dodge retaliation rare, and limit chance draws
  to one roll per ability.
- [x] Update canonical Talent behavior notes, inspect every Companion's viable
  ability pool, and audit all 149 descriptions for their tree keyword,
  player-facing voice, and feedback density with all nodes equipped.
- [x] Build affected packages, run pinned formatting/lint and docs checks,
  verify generated output stability, and review the final diff. Do not add or
  run tests without an explicit request in this task.

Panther's Arterial Cascade uses the existing action-group feedback consolidation
for Bleed damage and consumes Bleed on each qualifying Critical Hit, so another
detonation requires another Bleed application. Trophy Scales follows the user's exact
Block-break rule. Carrion Claim is provisionally renamed Shared Spoils with
the requested always-on 2-Health transfer. Warning Bark's Block wording is
provisional while retaining its Dodge behavior.

The first 149 Companion rows match their approved plan descriptions, all mention
their tree keyword, and the remaining six Companions' rows are unchanged.
The initial Companion implementation pass compiled BattleEngine and its test
targets, passed SwiftFormat, SwiftLint, documentation, generated-output
idempotence, and diff checks, and retired six obsolete checks. It deferred test
execution and isolated handoff. A later outstanding-change review reconciles
the remaining tests with approved rules, adds focused Companion regressions,
and runs routed, isolated handoff.

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

## Bear · Block — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Thick Hide | While you have Block, take 2 less Physical damage | Accept proposal |
| Hibernation | End your turn with Block to restore 2 Health | Accept proposal; wording only |
| Grizzly Guard | When your ally first falls below half Health, grant 6 Block | Accept proposal |
| Tough Pelt | While you have Block, Bleed damage is halved | Accept proposal |
| Ironhide | Attacks that break your Block deal half their remaining damage | Accept proposal |
| Vital Armor | Below half Health, gain 50% more Block | Accept proposal |
| Aftershock Guard (was Avalanche Guard) | Stunning an enemy doubles your next Block gain | Accept proposal |

## Bear · Physical — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Shield Breaker | Physical attacks deal double damage to enemy Block | Keep effect; wording only |
| Primal Rage | When Block breaks, your next Physical attack gains 2 damage | User magnitude revision; bonus stays in the Physical hit |
| Cleaving Claws | Bleeding enemies take 25% increased Physical damage | Accept proposal |
| Heavy Impact | Stunned enemies take 25% increased Physical damage | Accept proposal |
| Enrage | Below half Health, Physical attacks gain +25% Critical Hit chance | Accept proposal |
| Pulverize | Physical Critical Hits remove all enemy Block | Accept proposal |
| Battering Ram | Your first Physical attack each turn gains half your Block as damage | User magnitude and wording revision |

## Bear · Stun — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Ground Slam | Your first Stun attack each turn deals 3 additional damage | Accept proposal |
| Dazing Swipe | Physical attacks have a 10% chance to deal 4 Stun damage | Accept proposal; roll once per ability |
| Shockwave | Stun attacks ignore half enemy Block | Accept proposal |
| Deep Stun | Stun has a 20% chance to last another turn | Keep effect; wording only |
| Exposed Prey | Stunned enemies take 25% more damage from your ally | Accept proposal |
| Seismic Roar | Below half Health, your Stun build-up increases by 50% | Accept proposal |
| Seismic Reversal | When your Block breaks, return absorbed damage as Stun | Accept proposal |

## Frost Whelp · Freeze — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Rimewind | Freeze damage has a 10% chance to draw a card | User revision; once per Freeze ability, excluding Talent retaliation |
| Chilling Scales | Taking damage has a 10% chance to return 4 Freeze damage | Accept proposal; roll once per enemy ability |
| Glacial Grip | Increase Freeze build-up by 20% | Accept proposal |
| Frost Siphon | Freezing an enemy restores 2 Mana | Accept proposal |
| Shatter Frost | Frozen enemies take 25% increased damage | Wording only |
| Freezing Gale | Freeze Critical Hits double Freeze build-up | Accept proposal |
| Winter’s Dominion (was Elemental Paradox) | Freezing an enemy draws a card | User effect revision |

## Frost Whelp · Mana — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Dragon Spark | Spending Mana has a 10% chance to draw a card | User effect revision; roll once per ability |
| Arcane Breath | Mana empowerment adds 1 damage to Freeze attacks | Accept proposal |
| Mana Absorption | Excess Mana restored becomes Block | Accept proposal |
| Aetherial Armor | While you have Mana, take 25% less damage | Accept proposal |
| Mana Flow | Spending Mana has a 25% chance to refund it | Accept proposal; roll once per ability |
| Spell Channeling | Mana empowerment costs 1 less Mana | Wording only |
| Dragon’s Patronage | Mana empowerment grants your ally 2 Block | User effect revision; once per empowered ability |

## Frost Whelp · Dodge — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| High Altitude | Above half Health, gain +15% Dodge chance | Wording only |
| Tailwind | Your first Dodge each combat draws a card for your ally | Accept proposal |
| Flyby Strike | Dodging makes your next attack Critically Hit | Accept proposal |
| Wing Buffet | Deal 2 Freeze damage when you Dodge | User revision |
| Aerial Cover | Dodging an attack grants the Hero 3 Block. | Keep current effect and text |
| Tempest Wing | Dodging makes your next Mana empowerment free | Accept proposal |
| Winter’s Wake | Dodging makes your next Freeze attack ignore enemy Block | Accept proposal |

## Lizard Scout · Poison — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Cold Blood | Deal 2 Poison damage when you Dodge. | Keep current effect and text |
| Venomous Skin | Deal 1 Poison damage to attackers when you take damage. | Keep current trigger; user reduced damage from 2 to 1 |
| Spit Poison | Poison attacks deal 1 additional damage to Bleeding enemies | User reduced proposal from 2 to 1 Poison damage |
| Toxiphage | Poison Critical Hits gain Leech | Accept proposal |
| Paralysis | Poison attacks have a 10% chance to Stun | Accept proposal; roll once per ability |
| Venom Spores | Poison has a 20% chance to not decay | User revision; roll each decay opportunity |
| Toxic Coma | Stunned enemies take 20% increased Poison damage | User magnitude revision |
| Cross-Contamination | Bleed Critical Hits also deal 4 Poison damage | Accept proposal |

## Lizard Scout · Bleed — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Barbed Tail | Dodging has a 20% chance to deal 4 Bleed damage | User-approved feedback revision; one roll per Dodge |
| Spiny Carapace | Bleed Critical Hits grant 2 Thorns | User revision |
| Ferocious Bite | +10% Critical Hit chance against Bleeding enemies | User revision |
| Evasive Reflexes | Gain +10% Dodge against Bleeding enemies | Wording only |
| Frenzied Tail | Bleed Critical Hits have a 20% chance to draw a card | User revision; roll once per ability |
| Armor Shred | Bleed attacks deal 50% more damage to enemy Block | Accept proposal |
| Butcher’s Cut (was Butcher’s Ledger) | Enemies below half Health take 30% increased Bleed damage | User magnitude revision |

## Lizard Scout · Gold — approved, Shared Spoils name provisional

| Talent | Final description | Decision |
| --- | --- | --- |
| Trophy Scales | Steal 3 Gold when your Block is broken | User revision; depends on external Block or Hoard Armor |
| Hoard Armor | Stealing Gold has a 10% chance to grant 4 Block | User revision; roll once per ability |
| Pickpocket | Critical Hits steal 3 Gold | Accept proposal |
| Scavenger’s Cache | Stealing Gold has a 10% chance to draw a card | User revision; roll once per ability |
| Flawless Bounty | Excess Leech restoration on you is converted to Gold | User clarification; 1 Gold per excess Health |
| Gilded Claws | Gold stolen adds equal damage to your next attack | Accept proposal |
| Shared Spoils (was Carrion Claim) | Stealing Gold restores 2 Health to your ally | User effect, corrected grammar; provisional thematic name |

Trophy Scales depends on Block despite Scout having no Block ability in its
loadout; Hoard Armor's 10% proc or an ally's Block grant makes it viable.
Cold Blood retaliates on every Dodge. Barbed Tail's rare roll keeps the two
typed retaliation chips from appearing together on most Dodges.

## Panther · Bleed — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Razor Claws | Bleed attacks deal 1 additional damage | Accept proposal |
| Raking Swipes | Bleed attacks gain +10% Critical Hit chance | Accept proposal |
| Stalk the Wound | Bleeding enemies below half Health take 25% increased damage | User revision |
| Rend Flesh | Bleed Critical Hits deal 25% more damage | Accept proposal |
| Crippling Laceration | Enemies with 3 or more Bleed deal 30% less damage. | Keep current effect and text |
| Bloodprice | Bleeding enemies restore half as much Health | Accept proposal |
| Arterial Cascade | Critical Hits detonate Bleed | User revision; feedback aggregation and once-per-ability cadence to confirm |
| Redline | Dropping below half Health doubles your next Bleed attack | Accept proposal |

## Panther · Leech — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Blood Hunger | Bleed attacks gain Leech while below 30% Health | User revision |
| Shared Feast | Excess Leech Health restoration is shared with your ally | User revision; transfer excess only, no loss of owner's actual healing |
| Vitality Infusion | Leech Critical Hits grant your ally 3 Block | Accept proposal |
| Sanguine Resistance (was Sanguine Growth) | Enemies cannot Leech from you | User name and effect revision |
| Frenzied Feeding | Leech restores 20% more Health against Bleeding enemies | User revision |
| Pack Bloodlust | Your ally's attacks have a 10% chance to Leech | User revision; roll once per ability |
| Blood Feast | Bleed Critical Hits gain Leech | User revision; applies to the Critical Hit itself |

## Panther · Dodge — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Surprise Strike | Your first Dodge each combat doubles your next attack | Accept proposal |
| Counter Pounce | Deal 2 Bleed damage when you Dodge | User revision |
| Survival Instinct | Below half Health, gain +20% Dodge chance | Accept proposal |
| Stalker’s Precision | Dodging makes your next attack ignore enemy Block | Accept proposal |
| Regroup (was Shadow Camouflage) | Dodging has a 10% chance to draw a card | User name and effect revision; roll once per Dodge |
| Vanish | Dodging makes your next attack Critically Hit | Accept proposal |
| Killing Grace | Gain Critical Hit chance equal to half your Dodge chance | Accept proposal |

## Phoenix · Burn — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Blazing Feathers | Taking damage has a 10% chance to return 4 Burn damage | Accept proposal; roll once per enemy ability |
| Ignition Spark | Burn has a 20% chance to not decay | Accept proposal; roll each decay opportunity |
| Flame Shield | Burn attacks have a 10% chance to grant 4 Block | Accept proposal; roll once per ability |
| Explosive Embers | Burn Critical Hits deal 3 additional damage | Accept proposal |
| Molten Heat | Burn attacks deal 50% more damage to enemy Block | Accept proposal |
| Intense Heat | Burning enemies take 25% increased damage from your Critical Hits | Accept proposal |
| Furnace Rhythm | Burn Critical Hits restore 3 Mana | Accept proposal |

## Phoenix · Health — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Restorative Ashes | Below half Health, restore 50% more Health | Accept proposal |
| Healing Flames | Burn attacks have a 10% chance to restore 4 Health to the lowest ally | Accept proposal; roll once per ability |
| Afterglow | Surviving Death's Door restores 4 Health to both allies | Accept proposal |
| Radiant Health | At full Health, both allies gain +10% Critical Hit chance | Accept proposal |
| Phoenix Gift | Your ally's first fatal hit each combat revives them with 5 Health | Accept proposal |
| Ashen Vitality | Excess Health restored to you adds 2 damage to your next Burn attack | Accept proposal; preparation refreshes rather than stacks |
| Clean Slate | Excess Health restoration Cleanses 1 negative status effect | Accept proposal |

## Phoenix · Death's Door — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| From the Ashes | Entering Death's Door restores 6 Health | Accept proposal; first fatal hit now enters Death's Door |
| Lingering Spirit | Death's Door lasts 1 additional turn. | Keep current effect and text |
| Blazing Rebirth | Entering Death's Door deals 4 Burn damage to the enemy | Accept proposal |
| Phoenix Vigor | Surviving Death's Door doubles your next attack | Accept proposal |
| Fortified Rebirth | Death's Door halves damage you take | Accept proposal |
| Ashen Ward | Death's Door prevents negative status effects | Accept proposal |
| Undying Ember | Burn damage gains Leech while you're on Death's Door | User revision; outgoing Burn damage, including ongoing damage |

## Golden Retriever · Gold — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Bounty | Defeating an enemy grants 3 Gold | Wording only |
| Dig for Treasure | Gain 2 Gold every 3 turns. | Keep current effect and text |
| Haggler | Steal 1 additional Gold | Accept proposal |
| Golden Guard | Stealing Gold increases your next Block gain by 50% | Accept proposal |
| Fetch! | Your first Gold steal each combat draws a card | Accept proposal |
| Treasure Hoard | Gaining Gold has a 10% chance to draw a card | User revision; only during live combat, once per Gold-gaining ability |
| War Chest | Your ally gains Critical Hit chance equal to Gold gained this combat | User revision; cumulative Gold, one percentage point per Gold |

## Golden Retriever · Block — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Guardian | Grant your ally 5 Block before their first incoming attack | Accept proposal |
| Watchful Eye | Start combat with 3 Block | Wording only |
| Shield Bond | Your first Block gain each turn is shared with your ally | Accept proposal |
| Warning Bark | Dodge the first enemy attack each combat without spending Block | Keep current Dodge effect; provisional wording mentions Block |
| Sacrificial Guard | Your Block also absorbs damage dealt to your ally | User-approved pairing; Retriever Block protects Hero before Hero Block |
| Steadfast | While you have Block, prevent Stun and Freeze build-up | Accept proposal |
| Shield Relay (was Icebound Exchange) | When your Block breaks, your ally gains 2 Block | User magnitude revision |

## Golden Retriever · Health — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Cheer Up | Your first Health restoration each combat draws a card | User revision; actual restoration only |
| Playful Energy | Restoring Health has a 10% chance to draw a card | User revision; roll once per restoring ability |
| Campfire Comfort | At turn end, restore 3 Health to the lowest Health ally | Accept proposal |
| Man's Best Friend | Intercept the first damage each combat that would reduce your ally's Health to zero | User-approved pairing; once per combat after Block absorption |
| Inspirational Vigor | Below half Health, both allies gain +15% Critical Hit chance | Accept proposal |
| Protective Lick | Restoring Health also Cleanses 1 negative status effect | Accept proposal |
| Contagious Joy | Excess Health restoration on you is shared with your ally | User revision; transfer excess only |

## Library Owl · Holy — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Revealed Flaw | Holy Critical Hits make your ally's next attack ignore enemy Block | Accept proposal |
| Scholarly Smite | Holy attacks gain +15% Critical Hit chance | Accept proposal |
| Blinding Light | Holy attacks reduce the enemy's next attack accuracy by 20% | Accept proposal |
| Radiant Wisdom | Holy attacks have a 10% chance to draw a card | Accept proposal; roll once per ability |
| Bane of Evil | Holy Critical Hits Purge a positive status effect | User revision |
| Purifying Light | Holy attacks have a 10% chance to Cleanse your ally | User revision after feedback audit; roll once per ability |
| Interdict | Purging with Holy prevents that positive status effect from returning next turn | Accept proposal |

## Library Owl · Cleanse — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Purifying Wisdom | Your first successful Cleanse each combat draws a card | Accept proposal |
| Healing Hymn | Cleansing an ally restores 2 Health | Wording only |
| Spellbreak Shield | Cleansing a negative effect grants 2 Block per effect removed. | Keep current effect and text |
| Mass Cleanse | Your first successful Cleanse each turn also Cleanses your ally | Accept proposal |
| Reflective Ward | Cleansing a negative effect reflects it onto the enemy who applied it. | Keep current effect and text |
| Sanctified Scroll | Cleansing an ally grants +20% Critical Hit chance on their next attack | Accept proposal |
| Lesson Learned | Cleansed effects cannot return until your next turn. | Keep current effect and text |

## Library Owl · Health — approved

| Talent | Final description | Decision |
| --- | --- | --- |
| Safe Perch | At full Health, gain +10% Dodge chance | Accept proposal |
| Warded Roost | Restoring Health reduces that ally's next incoming damage by 20% | Accept proposal |
| Efficient Care | Restore 25% more Health | Accept proposal |
| Aether Shield | Restoring Health has a 10% chance to grant equal Block | User revision; healed ally receives Block equal to actual Health restored, one recipient per ability |
| Guardian Archive | When either ally enters Death's Door, they restore 8 Health | User revision |
| Font of Magic | Restoring Health or Mana has a 10% chance to draw a card | User revision; roll once per ability |
| Living Archive | Restoring Health has a 10% chance to grant 3 Thorns | User revision; healed ally receives Thorns, one recipient per ability |
