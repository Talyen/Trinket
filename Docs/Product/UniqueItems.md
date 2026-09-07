# Unique equipment

The collection has one Unique for each of the 29 weapon, armor, and accessory
bases. Trinkets remain a separate category. Uniques use their base item's artwork
and the existing singleton ownership, equipment, reward, and corruption rules.

## Catalog contract

The authored [Unique catalog](../../Packages/TrinketContent/Sources/TrinketContent/Content/UniqueCatalog.swift)
owns identities and powers. Each Unique has an exclusive signature and three
fixed supporting powers, resolved at the catalog's Astral values without RNG.
Item-local pinned supports reuse standard powers when their slot or affinity
needs adaptation; they never enter ordinary affix pools. Existing owned items
keep their identities, and new trigger fields decode to inactive defaults in
older affix payloads.

Every Unique also appears in an explicit thematic
[Mystery reward pool](MysteryEvents.md). Those placements retain each offer's
ordinary gear fallback and existing rarity probabilities.

The original eight Trinket signatures remain unchanged. The following additions
adapt Alchemy's item names and base pairings to Trinket's combat rules. Their
identifiers use underscores.

## Completion signatures

| Base | Unique | Signature |
|---|---|---|
| Double Axe | The Unclosing Wound | Your Bleed continues after its normal duration, halving in potency each additional turn. |
| Maul | Kingbreaker | Your Stun damage ignores enemy Block and gains damage equal to that Block. |
| Greatsword | Everkeen | Once per turn, your first Critical Hit strikes again. |
| Hatchet | Red Harvest | Once per turn, an attack card you play against a Bleeding enemy returns to your hand. |
| Longsword | Oathkeeper | Your Physical damage bonuses also strengthen Holy damage. |
| Shortsword | The Patient Edge | Each of your cards left in hand at turn end adds 2 damage to your first attack next turn. |
| Dagger | Viper’s Courtesy | After Dodging, your next hit deals additional Poison and Bleed damage, each equal to half its damage. |
| Mace | The Lingering Bell | Stunning an enemy preserves a quarter of the Stun buildup that triggered it. |
| Longbow | Huntsmaster’s Call | Your first Critical Hit each turn makes your Companion use its Basic Ability. |
| Shortbow | Wrenflight | Playing your second card each turn draws a card and grants 10% Dodge until your next turn. |
| Recurve Bow | The Returning Gale | The third card you play each turn returns to your hand after resolving. |
| Wand | The Final Spark | Once per turn, spending your last Mana to empower a Burn or Freeze card repeats its damage. |
| Leather Buckler | Laughing Guard | Keep Block between turns. Dodging spends half your Block to deal that much Physical damage. |
| Kite Shield | The Knight’s Answer | The first time each turn your Block absorbs attack damage, immediately use your Basic ability. |
| Quiver | The Returning Flight | At turn start, recover your last attack card from the previous turn, if it remains in your deck. |
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
start of the play. The Returning Flight recovers from the wearer's deck before
normal turn draws and does nothing if the card is already held or absent.
The Patient Edge counts the wearer's visible and buffered cards when the player
ends the turn; its bonus affects the first damage component of the first attack
next turn and expires if unused. Threefold Grace grants one draw for each new
matching elemental allowance, including multiple draws for a mixed card.

Everkeen reuses the triggering packet's outgoing magnitude and Critical
multiplier against current defenses; it does not roll or multiply Critical
damage again. The Final Spark repeats resolved damage components and their
normal damage riders without another empowerment purchase or utility effects.
Huntsmaster's Call and The Knight's Answer use full equipped Basic abilities,
including utility effects, with normal targeting, resource requirements, and
survival/control restrictions; they do not consume a deck card.

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
