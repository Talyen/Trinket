# Library and Archery crafting

Library contains **Bestiary** and **Research**. Adventures record discoveries and
complete finite projects, which teach nine focused recipes across Archery Range,
Blacksmith and Outfitter. It uses existing artwork and normal Homestead
access. Collection remains the home for Trinkets and Uniques. There is no research
currency, item archive, timer, acceptance/claim step or Where to find feature.

Design references and their concept-only limitations are in the [mockup notes](LibraryDesign/Mockups.md).

## Bestiary

The 39 enemies, including bosses, stay together in authored catalog order. The
gallery contains only landscape artwork: no names, status text, completion badge,
legend, discovery groups or question-mark placeholders. Undiscovered art is fully
grayscale and disabled. The first actual encounter restores original color and
enables inspection; victory is unnecessary. Defeated enemies have no separate
Bestiary treatment. Previewing or inspecting an enemy never records discovery.

Colored cards open the existing combatant detail sheet used in battle. It shows
the name, traits, abilities and level-qualified stats, using the current Standard
Contract reference scaling. It has no editing controls, fabricated live effects,
extra research section or separate Bestiary detail page. Dismissal preserves the
gallery position. Battle/encounter inspection of an active opponent is unaffected.
Tap, deferred presentation and accessibility activation share the same live
discovery/save-generation gate. Unknown entries retain generic unavailable
accessibility semantics without visible labels.

Landscape scenes retain their prepared source framing, about 4:3. Compact windows
use one column and a small consistent gap. Wider layouts may add columns while
preserving the art. Load visible/adjacent thumbnails; never warm the full catalog
at full resolution. Existing first-screen preparation and owner pins remain.

## Research

Research tracks all facts automatically, including before Library is built.
Completion requires the project's facts and Library tier. A later upgrade applies
already-earned facts without repeated battles. Completion and learned recipes are
permanent within the save/reset epoch. Library IV retains its existing XP benefit
without filler research. Research has no flavor-only projects or archive rewards.
Projects have at most three independently completable
objectives; a grouped checklist cannot conceal extra targets.

| Project | Library | Objectives | Reward |
|---|---:|---|---|
| Forest Field Notes | I | Defeat Slime, Goblin, The Blight Treant | Poison Shortbow recipe |
| Predator Anatomy | II | Defeat Giant Spider, Giant Snake, Dire Wolf | Bleed Longbow recipe |
| Arms and Armor | III | Defeat Goblin, Bandit, Living Armor | Physical Crossbow recipe |
| Serrated Steel | I | Defeat Bandit, Dire Wolf | Bleed Greatsword recipe |
| Consecrated Arms | II | Defeat Cleric, Paladin | Holy Mace recipe |
| Shieldcraft | III | Defeat Living Armor, Stone Golem | Block Kite Shield recipe |
| Reinforced Leather | I | Defeat Goblin, Living Armor | Block Leather Armor recipe |
| Venomproof Leather | II | Defeat Giant Spider, Giant Snake | Poison Leather Armor recipe |
| Sanguine Leather | III | Defeat Vampire, Blood Cultist | Leech Leather Armor recipe |

Named enemies are separate defeat objectives. Duplicate kills cannot substitute
for other targets. Unknown enemy IDs do not satisfy these goals. Source identities
and stable project IDs
live in the authored Content catalog, not in the feature UI.

The browser uses compact illustrated recipe rows, a project title, short recipe
name and at most three small objective marks. In Progress and
Completed replace a filter/dashboard. Capture section ordering for the visit;
newly completed rows update in place and move sections on the next visit.

Recipe-project detail shows a modest 3:4 portrait reward, then up to three
landscape target thumbnails. Target names and defeat checks belong here. Only
undiscovered enemies are grayscale; an encountered-but-not-defeated target stays
colored with an open check. Discovered targets reuse combatant inspection;
undiscovered targets are disabled. Cards adapt to native text sizes instead of
truncating names. A required
Library tier stays visible when it blocks completion.

The reward image/name opens a read-only recipe preview. There is no repeated
workshop subtitle, purpose paragraph, Reward heading, View Recipe button or
location/source disclosure. A successful current victory can show one compact
completion notice;
Library upgrades expose a quiet summary after their existing celebration.
Background/reset retire transient notices; opening history never replays them.

## Archery Range

Range I exposes Craft; standard crafting does not require Library. Standard
recipes keep authored order. Focused recipes use compact portrait rows, with
learned recipes before locked recipes in an order captured when the sheet opens.
Locked recipes remain inspectable and name their research requirement, with one
primary View Research action until learned. Focused previews use the expanded sheet. Every
equipment image, including small reward/recipe thumbnails and actual results,
uses 3:4 portrait proportions. Resource icons retain their existing proportions.

| Recipe | Wood | Iron | Hide | Herbs |
|---|---:|---:|---:|---:|
| Shortbow | 32 | 16 | 0 | 0 |
| Longbow | 40 | 20 | 0 | 0 |
| Recurve Bow | 40 | 20 | 0 | 0 |
| Crossbow | 32 | 32 | 0 | 0 |
| Quiver | 16 | 0 | 32 | 0 |
| Poison Shortbow | 48 | 24 | 0 | 8 |
| Bleed Longbow | 60 | 30 | 12 | 0 |
| Physical Crossbow | 48 | 48 | 0 | 0 |

These are the initial authored prices. Tune against actual resource income,
passive production, Blacksmith prices and salvage; they establish no time-to-earn
promise. No individual craft returns all its input materials through salvage.
Quiver converts Hide/Wood into Iron/Wood; assess conversion cycles rather than
requiring a loss of every individual resource.

Standard recipes use normal Basic/Astral/selected-base unowned Unique outcomes,
excluding Trinkets. Focused recipes produce only Basic or Astral and guarantee
one affix with their named keyword, occupying a normal affix slot. Remaining rolls
are normal. The recipe name does not rename the item base. Range tiers II–IV add
10/20/30% Range-only Astral tier weight, independently of global drop bonuses.
Reward level remains the highest won encounter level, with the existing loot cap.
No building bonus, production rate, upgrade cost or Blacksmith recipe is removed.

Both workshops share the existing sheet, cost dock, immutable roll and actual-item
reveal. Persistence resolves the catalog recipe, tier, research unlock and current
balances before spending. Retry retains the same candidate, revalidates eligibility,
and commits debit/insertion once. No automatic equip. Dismissal/background suppress
late reveals while retaining an accepted item; reopening never crafts again.

## Navigation and ownership

Library screens use the existing Homestead path. Recipe previews opened from a
project are read-only, with Open Archery Range leading to the actual building and
its single Craft sheet. An unbuilt Range keeps its normal Build requirement.
Inside Craft, View Research pushes the project into that same sheet. Discovered
target inspection there reuses combatant content on the current sheet stack.
Links pop to an existing ancestor instead of growing a project/recipe loop.
Back returns to the actual origin; no new global router or nested sheet is needed.

Content owns project facts, evaluation and immutable recipe/craft rules.
Persistence owns history, atomic settlement, storage, migration, reset and cloud
merge. AppState reports successful battle activation and consumes committed
completion feedback. Feature UI observes narrow save slices. No new package,
generic quest engine or item-discovery hooks are required. Save compatibility is
owned by [storage](../AgentContext/persistence-storage.md#library-history).

## Blacksmith and Outfitter research recipes

| Recipe | Cost |
|---|---|
| Bleed Greatsword | 60 Iron + 30 Wood + 12 Hide |
| Holy Mace | 48 Iron + 24 Wood + 8 Gems |
| Block Kite Shield | 48 Iron + 24 Wood + 8 Stone |
| Block Leather Armor | 60 Hide + 30 Wood + 12 Iron |
| Poison Leather Armor | 60 Hide + 30 Wood + 12 Herbs |
| Leech Leather Armor | 60 Hide + 30 Wood + 12 Gems |

Each guarantees an ordinary affix with the named keyword, occupies a normal slot,
and produces Basic/Astral only. Item names remain their base names. Cross-links
name the actual workshop and reuse its existing ancestor rather than growing
recipe/project loops. Historical Companion Chronicles/Spire Records completion
IDs survive as inert save data; neither project is evaluated or displayed.
