# Library and Archery crafting

Library contains **Bestiary** and **Research**. Adventures record discoveries and
complete finite projects, which teach focused recipes across Archery Range,
Blacksmith and Outfitter. It uses existing artwork and normal Homestead
access. Collection remains the home for Trinkets and Uniques. There is no research
currency, item archive, timer, acceptance/claim step or Where to find feature.

Design references and their concept-only limitations are in the [mockup notes](LibraryDesign/Mockups.md).

## Bestiary

All catalog enemies, including bosses, stay together in authored catalog order. The
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

[ResearchProject.all](../../Packages/TrinketContent/Sources/TrinketContent/Homestead/LibraryResearch.swift)
owns project IDs, Library tiers, enemy objectives and recipe rewards.

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

[EquipmentRecipe](../../Packages/TrinketContent/Sources/TrinketContent/Homestead/BlacksmithRecipe.swift)
owns standard/focused recipe order, workshop membership, costs and research links.
Tune prices against actual resource income, passive production, Blacksmith costs
and salvage; they establish no time-to-earn promise. No individual craft returns all its input materials through salvage.
Quiver converts Hide/Wood into Iron/Wood; assess conversion cycles rather than
requiring a loss of every individual resource.

Standard recipes use normal Basic/Astral/selected-base unowned Unique outcomes,
excluding Trinkets. Focused recipes produce only Basic or Astral and guarantee
one affix with their named keyword, occupying a normal affix slot. Remaining rolls
are normal. The recipe name does not rename the item base. Later Range tiers add
the catalog's workshop-only Astral tier-weight bonus,
independently of global drop bonuses.
Reward level remains the highest won encounter level, with the existing loot cap.
No building bonus, production rate, upgrade cost or Blacksmith recipe is removed.

All workshops follow [Homestead's crafting commitment and reveal contract](Homestead.md#blacksmith-crafting).
Persistence also revalidates the research unlock before spending. No automatic equip.

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

The recipe catalog's `focusedBlacksmith` and research-gated `outfitter` entries
own these recipes and prices. Each guarantees an ordinary affix with the named
keyword, occupies a normal slot,
and produces Basic/Astral only. Item names remain their base names. Cross-links
name the actual workshop and reuse its existing ancestor rather than growing
recipe/project loops. Historical Companion Chronicles/Spire Records completion
IDs survive as inert save data; neither project is evaluated or displayed.
