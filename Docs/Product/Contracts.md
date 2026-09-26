# Contracts

Contracts is a renewable, one-battle mode for developing any Hero and Companion
and earning regular battle loot. It is available in Play → Explore immediately
after starter selection, on both new and existing saves.

## Board

Three offers appear in Easy, Standard, Hard order. Every ordinary enemy is
eligible for Easy and Standard; every boss is eligible for Hard, independent of
discovery or completion elsewhere. The two ordinary targets are distinct.

Let P be the active Hero and Companion's average level, rounded down:

| Offer | Target | Level |
|-------|--------|-------|
| Easy | Ordinary enemy | max(1, P − 3) |
| Standard | Ordinary enemy | P |
| Hard | Boss | P + 3 |

Use the existing enemy curves, shared
[progression-based loot policy](../../Packages/TrinketContent/README.md#random-item-rewards)
with the highest won encounter level anchoring item quality (capped at loot level 40).
The victory being claimed uses its own encounter level for its item roll and records
that level for later offers. Contract encounter level also drives XP, Gold, and material quantities.
Hard Contracts receive the shared
boss loot weighting. Preserve catch-up XP, shared level-difference XP scaling, reward
ownership, and applicable Homestead effects. Higher-level enemies award more XP
under the shared curve; Hard has no additional difficulty-specific XP multiplier.
Difficulty labels describe level and enemy category, not a guaranteed matchup outcome.

Use the shared Stage screen, list, and active-card layout from Campaign and Spires.
All three offers are available Stage cards, showing difficulty (Easy, Standard,
Hard), enemy artwork/name, and Battle. Cards use the same 16-point gap as Game
Mode cards; Campaign and Spires retain their compact stage spacing. Enemy artwork
opens enemy details at the resolved encounter level.
Each card has a Party control beside Battle that opens the existing party picker
for the shared active Hero and Companion. Each offer overlays its reward modifier on the artwork using the shared
Node modifier caption style: colored icon and concise effect text without
thematic modifier names or percentages. Exact payouts appear after battle. Reuse Explore art
and existing enemy portraits.

## Reward modifiers

Contracts, Labyrinth combat nodes, and Voyage combat nodes share the
[reward modifier catalog](../../Packages/TrinketContent/README.md#shared-reward-modifiers).
Contracts choose uniformly among its eligible entries.

Each offer saves one modifier regardless of difficulty. Gold, XP, and Materials bonuses increase their category by 25%.
Wood, Stone, Iron, Food, Herbs, Hide, and Gems bonuses guarantee that resource in
one of the two material slots and increase its quantity by 25%; the other slot
remains random and distinct. Existing quantity rounding and reward caps apply.

Astral, Trinket, and Unique bonuses double the selected eligible item-tier weight
after progression, boss, and Homestead weighting, then normalize
the probabilities. They do not add percentage points or extra items. Unowned-item
eligibility remains authoritative: exhausted Trinket/Unique pools are excluded
from generation, and an existing offer targeting an exhausted pool displays and
applies Bonus Gold instead. The board and launch resolve the same effective bonus.

Keyword modifiers display “Drops [Keyword] items” and guarantee one Basic or
Astral item with both a matching base affinity and at least one matching affix.
The guarantee uses a normal affix slot, carries no additional percentage bonus,
and leaves Gold, XP, and materials unchanged. Basic/Astral relative tier weights
retain progression, boss, and Homestead adjustments; collectible tiers are excluded.

Arms, Armor, Ring, and Amulet Hoards guarantee the normal victory item belongs
to that family, using only Basic/Astral tiers with their ordinary relative
weights and affixes. Arms includes off-hand Weapon-slot bases; Rings and Amulets
are distinct Accessory bases. Astral, Trinket, and Unique Hoards instead
guarantee the named tier. They grant the normal single item, not an extra item.
The existing Astral Omen, Relic Seeker, and Lost Legacy remain weight bonuses,
not guarantees. Exhausted Trinket/Unique Hoards follow the same Bonus Gold
fallback as their weight-bonus counterparts.

Legacy offers without a modifier retain their IDs and targets and gain Bonus Gold.
Party changes and retries retain the saved modifier; refresh and victory replacement
roll a new one. XP bonuses are baked into the launch reward plan, including the
shared partial-defeat calculation. Item and material bonuses grant nothing on defeat.

## Lifecycle

One full-board refresh is earned by a Contract victory; the board starts with none
and holds at most one. Refresh consumes it and replaces all offers. Victory replaces
only the completed offer; avoid immediately repeating its target when possible.
Defeat and retreat retain the offer for free retries. Defeat grants the shared
[partial battle XP](../AgentContext/persistence-progression.md); retreat awards nothing. Each
attempt starts with the existing fresh-battle state.

The board persists between visits and app launches. Party changes and level-ups
retain targets. Encounter levels and loot are resolved only when Battle is pressed,
using the active party at that moment. Each attempt fixes its party, level, and
loot at launch; victory pays those rewards using
the normal victory and talent-choice flow before returning to Contracts.

Claiming rewards and replacing the offer is one saved operation. A duplicate or
stale offer claim cannot pay again; failed writes retain the board and pending
victory for retry. App interruption follows the existing battle lifecycle: an
interrupted, unclaimed offer remains available rather than adding mid-battle
save/resume. Missing or unreadable offers can regenerate independently of
other saved progress; a readable saved loot milestone and earned refresh are
retained when offers are damaged.

Contracts has no entry cost, timers, separate statistics, ranks, bonus
objectives, or overall completion percentage. Its lasting rewards are roster
progression, equipment, gold, and materials.
