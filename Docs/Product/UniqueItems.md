# Unique equipment

The collection has one Unique for each of the 29 weapon, armor, and accessory
bases. Trinkets remain a separate category. Uniques use their base item's Astral artwork
and the existing singleton ownership, equipment, reward, and corruption rules.

Collection shows the full authored Unique and Trinket catalogs, with owned items
first and missing entries locked in catalog order. Locked cards share the hero and
companion treatment and cannot open details. Basic and Astral Gear show only owned
items; Unique Gear slot filters include locked entries.

## Catalog contract

The authored [Unique catalog](../../Packages/TrinketContent/Sources/TrinketContent/Equipment/UniqueCatalog.swift)
owns identities and powers. Each Unique has an exclusive signature and three
fixed supporting powers, resolved at the catalog's Astral roll-max values
without RNG. Only the signature trait and the item name use the Unique gold
shine; supporting traits use their normal keyword-based shine.
Item-local pinned supports reuse standard powers when their slot or affinity
needs adaptation; they never enter ordinary affix pools. Existing owned items
keep their identities, and new trigger fields decode to inactive defaults in
older affix payloads.

Every Unique also appears in an explicit thematic
[Mystery reward pool](MysteryEvents.md). Those placements retain each offer's
fixed ordinary gear base and use the shared
[progression-based loot policy](../../Packages/TrinketContent/README.md#random-item-rewards).
Owned or ineligible Uniques leave the available pool before category selection.

The original eight Trinket signatures remain unchanged. The following additions
adapt Alchemy's item names and base pairings to Trinket's combat rules. Their
identifiers use underscores.

## Completion signatures

| Base | Unique | Signature |
|---|---|---|
| Double Axe | The Unclosing Wound | Your Bleed continues after its normal duration, halving in potency each additional turn. |
| Maul | Kingbreaker | Your Stun damage ignores enemy Block and gains damage equal to that Block. |
| Greatsword | Everkeen | Your first Physical Critical Hit each turn strikes again. |
| Hatchet | Red Harvest | Once per turn, an attack card you play against a Bleeding enemy returns to your hand. |
| Longsword | Oathkeeper | Your Physical damage bonuses also strengthen Holy damage. |
| Shortsword | The Patient Edge | Blocking an attack makes your next attack Critically Hit. |
| Dagger | Viper’s Courtesy | After Dodging, your next hit deals additional Poison and Bleed damage, each equal to half its damage. |
| Mace | The Lingering Bell | Stunning an enemy preserves a quarter of the Stun buildup that triggered it. |
| Longbow | Huntsmaster’s Call | Your Bleed damage triggers your Companion's Basic Ability once per turn. |
| Shortbow | Wrenflight | Playing your second card each turn draws a card and grants 10% Dodge until your next turn. |
| Recurve Bow | The Returning Gale | Dodging returns the last card you played to your hand. |
| Wand | The Final Spark | Once per turn, spending your last Mana to empower a Burn or Freeze card repeats its damage. |
| Leather Buckler | Laughing Guard | Keep Block between turns. Dodging spends half your Block to deal that much Physical damage. |
| Kite Shield | The Knight’s Answer | The first time each turn your Block absorbs attack damage, immediately use your Basic ability. |
| Quiver | The Returning Flight | Your first Physical card each turn returns to your hand. |
| Spellbook | Threefold Grace | Your first Burn, Freeze, and Holy card each turn each draw a card. |
| Ruby Amulet | Bloodember Pendant | Burn and Bleed share their damage bonuses. |
| Sapphire Ring | Winter’s Credit | When empowering a Freeze card, spend 3 Block per missing Mana. |
| Emerald Ring | Serpent’s Eye | Your attacks against Poisoned enemies ignore Block. |
| Emerald Amulet | Wildheart’s Favor | Dodging draws a Poison card and guarantees your next Poison card’s damage Critically Hits. |
| Topaz Amulet | The Golden Crucible | Gold gained in combat adds equal damage to your next Holy hit. |

## Card cadence and reactions

Effects belong to the wearer. Ordinary plays include Auto Battle choices;
triggered cards, automatic Basic abilities, and damage repeats do not spend new
Unique card allowances or recursively activate the new repeat/counter effects.
Critical-hit triggers require a damage hit, not critical healing or a DoT tick.
Readied Dodge effects do not accumulate charges and survive until used or battle
end. Once-per-turn allowances reset for each wearer at the next player turn.

Card returns move abilities instead of creating deck copies. Finish the played
card's effects and on-play draws before returning it. The existing visible hand
and FIFO buffer both accept returned cards. Red Harvest checks Bleed at the
start of the play. The Returning Flight returns the wearer's first played
Physical card each player turn after effects and on-play draws (count Physical
via shared card identity; claim before returning so replaying cannot return
again; move the actual card, never cycle into the deck). The Returning Gale
tracks the wearer's last ordinary card play (including non-damaging; automatic
abilities never replace it) through the enemy turn. On the wearer's Dodge, move
that exact ability from its deck back to hand via normal card-return rules (do
nothing if already held/buffered, absent, or unavailable; repeated Dodges create
no copies). The hand survives into the next player turn (visible or buffered,
FIFO preserved) through normal turn-start draws. The two card-return signatures
work together without duplicating the same ability. Existing saved signatures
resolve to the new rules (Patient Edge held-card/partner-damage fields migrate
to Block-prepares-Crit; Loyal Companion per-turn fields migrate to heal-draw).
Threefold Grace grants one draw for each new matching elemental allowance,
including multiple draws for a mixed card.

Everkeen retains one repeat per wearer per player turn but requires a Physical
Critical Hit (earlier non-Physical Crits never spend the allowance). It reuses
the triggering packet's outgoing magnitude and Critical multiplier against
current defenses; it does not roll or multiply Critical damage again. The Final
 Spark repeats resolved damage components and their normal damage riders without
 another empowerment purchase or utility effects. Huntsmaster's Call triggers on
 the wearer's positive Bleed damage (including ongoing, once per player-turn
 cycle; claim before the Companion uses its equipped Basic Ability) with normal
 targeting, resource, control, and living restrictions; Companion attacks and
 reaction chains never recursively summon themselves. Summons owed by
 in-progress damage resolve right after that damage completes rather than
 nesting inside its pipeline. The Patient Edge prepares
the wearer's next ordinary attack to Critically Hit after Block actually absorbs
attack damage (gaining Block alone and blocking ongoing damage never qualify;
refresh not stack; persist until consumed or combat ends). The Knight's Answer
uses full equipped Basic abilities, including utility effects, with normal
 targeting, resource requirements, and survival/control restrictions; they do
 not consume a deck card. Like Huntsmaster summons, answers owed by
 in-progress damage resolve right after that damage completes. Snapping Jaws
 counters behave the same way.

## Damage, status, and resource rules

- Kingbreaker snapshots enemy Block for each Stun packet, adds it before incoming
  mitigation, and bypasses Block without consuming it. Serpent's Eye checks
  Poison before each attack packet; other mitigation remains effective.
- Oathkeeper and Bloodember share applicable numeric damage bonuses, counting
  shared universal bonuses once. Resistances, durations, Leech and proc behavior
  stay separate. Stored DoT potency does not bake those bonuses a second time.
- Viper's Courtesy consumes readiness on the next ordinary card hit that causes
  Health loss. Each follow-up starts at half that loss and uses normal typed
  damage and status application.
- The Unclosing Wound preserves normal Bleed duration bonuses, then retains half
  potency after each subsequent tick until zero. Detonation includes this finite
  tail and preserves its source, even when the other party member detonates it.
- The Lingering Bell retains one quarter of the capped buildup that triggered
  Stun, using combat rounding. Restore it after recovery; it never bypasses
  active-control restrictions, and removing the status also removes retention.
- Laughing Guard prevents passive Block decay only. Its Dodge reaction spends
  half the Block present before on-Dodge grants. Explicit Block halving still
  works normally.
- Winter's Credit checks the full empowerment payment, spends available Mana,
  then pays exactly 3 Block per missing Mana. If unaffordable, the card still
  plays without that empowerment. Block spending does not trigger attack or
  Block-break rewards, and only actual Mana spending earns Mana-spend rewards.
- The Final Spark qualifies on a positive empowerment debit that empties Mana,
  before refunds. Free or entirely Block-funded empowerment cannot qualify.
- The Golden Crucible stores actual positive combat Gold attributed to the
  wearer. Starting Gold, another character's gains, and post-battle rewards do
  not contribute. Consume the bonus on the next ordinary Holy hit; Gold earned
  by that hit prepares a later hit.

Battle-local counters and readiness live in BattleEngine's in-memory state.
Inventory powers persist through the existing save graph; this collection does
not add a saved-battle schema. Verification ownership and the hand contract live
in the [BattleEngine guide](../../Packages/BattleEngine/README.md).
