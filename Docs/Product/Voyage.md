# Voyage

Voyage is the fourth Explore mode, below Contracts. It is available after starter
selection and offers repeatable, finite adventures without advancing Campaign.

## Offers and navigation

Three persistent offers appear in Easy, Medium, Hard order with distinct Chapter
locations. Offers draw only from accessible Chapters: Forest, Dungeon, and Desert
for free players; full-game owners draw three of those plus Tundra. Chapter
completion is not required. Refresh is free before embarking.

Each card reuses Chapter art, with difficulty above the location name, a distinct
eligible reward modifier when possible, the shared Party picker, and Embark
(`location.north.fill`). Refresh rerolls all three modifiers. The Explore card and board hero
use the compass-and-map Voyage artwork; the title is native UI text.

One Voyage can be active. Embark persists the complete generated route before
navigation. Returning from Explore resumes it directly. The route uses Campaign's
hero and stage layout, a difficulty/Voyage eyebrow, location title, and the saved
destination reward modifier on the hero artwork. The current node shows its modifier;
future nodes show their type and enemy without a modifier preview or node number.
Mystery outcomes remain concealed. Only the next uncleared node can be played.

The party can change between battles. Each attempt starts fresh. Defeat and retreat
retain the route for retry; shared defeat XP and retreat rules apply. Abandon
requires confirmation, retains earned rewards, and forfeits remaining progress
and the completion bonus. Completion shows Voyage Complete and Back to Voyages.
Only the used offer is replaced after completion or abandonment; prefer another
location if one is available without duplicating the other two offers.

## Route generation

| Difficulty | Battles | Shops | Mysteries | Recruits | Boss | Total |
|---|---:|---:|---:|---:|---:|---:|
| Easy | 3 | 1 | 2 | 1 | 1 | 8 |
| Medium | 4 | 1 | 3 | 1 | 1 | 10 |
| Hard | 5 | 2 | 3 | 1 | 1 | 12 |

Seeded generation starts with combat and ends with a boss. Middle ordering avoids
consecutive identical noncombat stops and more than two ordinary battles in a row.
Enemy bags exhaust before reshuffling and avoid repeating across bag boundaries.
Each battle, shop, and Mystery gets one applicable Labyrinth modifier, restricted
to that encounter. Combat includes the shared
[reward modifiers](../../Packages/TrinketContent/README.md#shared-reward-modifiers),
including guaranteed keyword equipment. Preserve the original combat/reward category
ratio, then choose within that category while avoiding the preceding modifier when
alternatives exist. Shops and Mysteries retain their existing modifier pools.
Combat modifiers include enemy opening Block, attack Leech, extra Block removal,
Purge, and 50% resistance to each damage type. Attack riders apply on every
landed direct hit; resistance reduces typed damage, including damage-over-time
ticks. Because Stun and Freeze buildup follows resolved damage, those wards
also reduce buildup. Physical and Freeze resistance
retain their existing saved IDs at the new 50% strength.
Recruit stops have no modifier. If no eligible recruit remains, replace that stop
with a Mystery; a mid-route eligibility change preserves the announced route order,
so this replacement can create adjacent Mysteries.

| Location | Ordinary enemies | Boss |
|---|---|---|
| Forest | Slime, Mud Elemental, Goblin, Will-o-Wisp | The Blight Treant |
| Dungeon | Skeleton, Mimic, Necromancer, Living Armor | The Iron Bear |
| Desert | Fire Elemental, Fire Imp, Hellhound, Pyromancer | The Forge Golem |
| Tundra | Frost Elemental, Winter Wolf, Ice Wraith, Yeti | The Frostwarden |

## Levels and rewards

Let P be the current Hero and Companion's average level, rounded down. Easy uses
max(1, P − 3), Medium uses P, and Hard uses P + 3. The boss uses the same offset and
normal boss strength. Each attempt captures its party, level, modifiers, and loot.

Battle XP, Gold, materials, and boss item weighting use shared policies. Equipment
quality follows the highest won encounter level, as in Contracts; this victory
uses its own level for its item roll. Completion adds 20% of combat
Gold and materials earned across successful nodes, including the boss, rounded
down once per resource. The basis includes combat and Homestead reward bonuses
before wallet-cap conversion, and excludes shops, Mysteries, defeat rewards, and
the completion bonus itself. Apply capacity/overflow rules to the final award;
do not multiply the completion bonus again. The final victory displays and commits
the combined payout atomically with Voyage completion.

Each offer saves one shared reward modifier. It applies to the final boss's normal
victory reward only; retreat, defeat, and abandonment do not pay it. Compatible
Gold, XP, and material bonuses add to the boss node's modifier. Two different
material focuses occupy the two material slots. If both modifiers affect items,
the boss rolls one item for each rule, with distinct saved IDs and collectible
ownership respected between rolls. The route's 20% completion bonus remains
separate. Exhausted collectible modifiers resolve to Bonus Gold, including on
legacy offers whose saved modifier is missing.

No entry costs, timers, separate currencies, or health carryover are introduced.

## Persistence

The Voyage save slice owns offers, a stable run ID, generated nodes, encounter
payloads, completion progress, and bonus accounting. Shop stock/purchases and
Mystery choices remain pinned using run-and-node encounter identities. Rewards
and progress commit together; duplicate and stale actions cannot claim again.
Use existing silent write retries and interrupted-battle behavior, without
mid-battle resume. Missing Voyage data initializes lazily. Unreadable or unsupported
Voyage payloads remain preserved and unavailable rather than resetting progress.
