# Unique equipment

The collection has one Unique for each of the weapon, armor, and accessory
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
Reworked Red Harvest, Huntsmaster’s Call, Threefold Grace, and Golden Verdict
signatures normalize their stored powers to current descriptions and triggers
while retaining item identity and any unrelated stored modifiers.

Every Unique also appears in an explicit thematic
[Mystery reward pool](MysteryEvents.md). Those placements retain each offer's
fixed ordinary gear base and use the shared
[progression-based loot policy](../../Packages/TrinketContent/README.md#random-item-rewards).
Owned or ineligible Uniques leave the available pool before category selection.

## Completion signatures

Use the authored [Melee](../../Packages/TrinketContent/Sources/TrinketContent/Equipment/UniqueCatalog+Melee.swift),
[Ranged](../../Packages/TrinketContent/Sources/TrinketContent/Equipment/UniqueCatalog+Ranged.swift),
[Offhand](../../Packages/TrinketContent/Sources/TrinketContent/Equipment/UniqueCatalog+Offhand.swift)
and [Accessory](../../Packages/TrinketContent/Sources/TrinketContent/Equipment/UniqueCatalog+Accessory.swift)
catalogs for base pairings, names, signatures and tuning values. Identifiers use
underscores. The sections below own interaction and compatibility rules that the
short catalog descriptions cannot fully express.

## Card cadence and reactions

Effects belong to the wearer. Ordinary plays include Auto Battle choices;
triggered cards, automatic Basic abilities, and damage repeats do not spend new
Unique card allowances or recursively activate the new repeat/counter effects.
Critical-hit triggers require a damage hit, not critical healing or a DoT tick.
Readied Dodge effects do not accumulate charges and survive until used or battle
end. Once-per-turn allowances reset for each wearer at the next player turn.

Card returns move exact physical copies instead of creating copies. Ordinary
played cards wait in discard until next turn. The Returning Flight returns the
wearer's first Physical card each player turn after effects and on-play draws;
claim before returning so replay cannot return again. The Returning Gale tracks
the last ordinary attack card copy through the enemy turn; support cards preserve
that selection and cannot return themselves.
On Dodge it moves that copy from discard or draw pile to hand at most once per
player-turn cycle. An identical ability held as a different copy does not prevent
recovery. Already-held, unavailable, or absent copies produce no return. Both
allowances reset at the next player turn. Hand and FIFO buffer survive turn changes.
Existing saved signatures resolve these rules without changing item identity.

Everkeen retains one repeat per wearer per player turn but requires a Physical
Critical Hit (earlier non-Physical Crits never spend the allowance). It reuses
the triggering packet's outgoing magnitude and Critical multiplier against
current defenses; it does not roll or multiply Critical damage again. The Final
Spark likewise captures outgoing damage and Critical results before defenses,
then repeats those components against current defenses without another
empowerment purchase or utility effects. Huntsmaster's Call draws
from the Companion's deck after each damaging Physical Critical Hit by its hero wearer.
 Normal Companion draw restrictions and the shared hand buffer apply. The Patient Edge prepares
the wearer's next ordinary attack to Critically Hit after Block actually absorbs
attack damage (gaining Block alone and blocking ongoing damage never qualify;
refresh not stack; persist until consumed or combat ends). Automatic Basics and
triggered cards leave it ready; only the next ordinary attack hit consumes it. The Knight's Answer
uses full equipped Basic abilities, including utility effects, with normal
 targeting, resource requirements, and survival/control restrictions; they do
 not consume a deck card. Answers owed by in-progress damage resolve right
 after that damage completes. Snapping Jaws
 counters behave the same way.

## Damage, status, and resource rules

- Kingbreaker snapshots enemy Block for each Stun packet, adds it before incoming
  mitigation, and bypasses Block without consuming it. Serpent's Eye checks
  Poison before each attack packet; other mitigation remains effective.
- Oathkeeper and Bloodember use the
  [shared numeric damage policy](../AgentContext/battle-damage.md#stored-damage-and-detonation).
  Resistances, durations, Leech and proc behavior stay separate. Shared attacks
  consume the same first-attack and prepared-damage
  allowances as the original type, including Bounty Blade, Soul Burn, Ashen
  Vitality, Redline, Nimble Fang, Feigned Miss, Phantom Counter, and Temper Cycle. Consuming a
  shared bonus leaves none for a later hit of the original type. Stored
  DoT potency does not bake those bonuses a second time.
- Viper's Courtesy consumes readiness on the next ordinary card hit that causes
  Health loss. Each follow-up starts at half that loss and uses normal typed
  damage and status application.
- The Unclosing Wound preserves normal Bleed duration bonuses, then retains half
  potency after each subsequent tick until zero. Detonation includes this finite
  tail and preserves its source, even when the other party member detonates it.
- The Lingering Bell retains one quarter of the capped buildup that triggered
  Stun, using combat rounding. Restore it after recovery; it never bypasses
  active-control restrictions, and removing the status also removes retention.
- Red Harvest detonates all remaining Bleed after a damaging Physical Critical
  Hit, using existing detonation rules. There is no turn allowance.
- Threefold Grace rolls on each positive Burn, Freeze, or Holy Health-damage
  packet dealt to an enemy by either party member, including periodic and reaction
  damage without enabling other keyword reactions on those paths. Success restores
  1 Mana to the item wearer through normal Mana-gain rules. Full Mana does not roll.
- Golden Verdict's Holy damage builds equal Stun. When that Holy hit completes
  a Stun, its Gold reward counts as theft and activates Gold-theft reactions.
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
  not contribute. Consume the bonus on the next Holy hit from a manually played
  card; automatic abilities and reactions retain the charge. Gold earned
  by that hit prepares a later hit.

Battle-local counters and readiness live in BattleEngine's in-memory state.
Inventory powers persist through the existing save graph; this collection does
not add a saved-battle schema. Verification ownership and the hand contract live
in the [BattleEngine guide](../../Packages/BattleEngine/README.md).

## Three-card draw additions

Hidden Cache now reads **Stealing Gold has a 20% chance to draw a card.** It rolls
once per successful stealing ability, with no combat or turn limit. Zero theft
and ordinary Gold gains do not qualify. Existing saved Smuggler's Map powers
normalize to this signature, removing its legacy victory Gold while retaining
unrelated modifiers and triggers.

Resourceful is an ordinary armor affix at both Basic and Astral tiers: **Draw a
card when your Block breaks while below half Health.** Enemy attack damage must
break positive Block; assess the living wearer's Health after damage and lethal
protection. Decay, voluntary Block spending, and self-damage never qualify. There
is no chance roll or turn allowance.

## Targeted inscription and wishes

Runesmith changes one permanently selected position on Basic/Astral gear only,
including corrupted gear. Uniques and Trinkets remain ineligible. Wishing Well
can favor one missing collectible within its normally selected battle-drop
category, without raising category drop rates. [Homestead](Homestead.md) owns
costs, eligibility, interaction, and Corruption behavior.
