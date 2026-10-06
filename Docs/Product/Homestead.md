# Homestead UX

Player-facing Homestead layout. Implementation and presentation tuning live in
`Trinket/Features/Homestead/`. [PD-012](Decisions.md) owns immediate purchases
without a confirmation dialog.

## Browsing and benefits

The overview keeps its full-bleed landscape hero, compact eight-resource wallet,
and Play Mode–style category cards: Farming, Crafting, Alchemy, Training, Arcana.
Cards show tier-sum constructed progress and push stable two-column portrait
building galleries. Buildings have centered names beneath their portraits, without
visible upgrade segments in the galleries. Gallery cards retain accessibility
upgrade values. Buildings retain thin borders without an
affordability glow. Every building is inspectable and has no prerequisite
buildings: materials alone determine whether its next tier can be purchased.
Tier-zero artwork uses 35% saturation in galleries and details; built buildings
use full color. A successful first build restores color smoothly after its offer
sheet dismisses. Existing built saves do not depend on other buildings. Galleries expose balances through Resources, without a
persistent wallet or repeated category hero. Returning from an upgrade refreshes
gallery artwork coloring without replaying the detail celebration.

Building details use full-screen portrait artwork, the building name, and native
gold Back/Resources toolbar controls matching the gallery. A separate Build/Upgrade
section pairs each building's catalog icon with the action and tier segments.
Completed buildings retain a noninteractive full tier bar.
Only building details hide the tab bar. Resources opens a compact expandable
wallet sheet with a Close control.

The bottom panel contains only current bonuses and production. It shares native
`thinMaterial` with Craft, Build, and Upgrade containers, including completed tier
progress. All use the same subtle border and rounded geometry for consistent
text legibility over artwork. Every bonus and production output
uses a full-width row: a top-aligned icon in a 36-point frame sits 8 points beside
a leading-aligned text column. A thematic row-title header sits 4 points above a
wrapping body-size description; both retain primary contrast. Benefits are separated
by 16 points. Names remain stable across tiers and are owned by the Homestead feature's
building/effect-key lookup. Details and offers share this layout; offers retain
their solid sheet background. Each effect keeps its own block, including buildings
with multiple bonuses or outputs. Descriptions contain bold values, preserve keyword formatting, and name production resources
explicitly (for example, “Produce 1 Food per Day”). Panel content scrolls as needed without
truncating descriptions. Completed buildings keep benefits and omit the build/upgrade action.

Bonus symbols reuse keyword identities and colors: Health uses heart.fill; healing
uses heart.circle.fill; damage uses its keyword symbol; damage resistance uses
shield.fill tinted to its keyword. Party protection uses Block styling; companion
damage uses pawprint.fill with Physical tint; ranged damage uses figure.archery with
Physical tint; Dodge uses wind; Astral finds uses sparkles with arcane tint; Gold finds
uses circle.circle.fill with Gold tint.
Production uses the same illustrated resource artwork as wallets, collection,
and purchase costs for every material. Material names use semantic colors: Iron
and Stone use Physical grey, Food uses Health red, and Wood, Hide, Herbs, Gems,
and Gold use their resource tints. Quantities and per-Day text retain primary
contrast.
Progress uses the catalog's actual tier count. No persistent completion banner,
checkmark, or Tier N label appears.

## Next-stage offers

Build/Upgrade opens the next-stage offer. First builds use **Build {building name}**
and show the resulting bonuses and production. Upgrade offers use only the building
name and show **Upgrade cost**, resource icons and costs, and the Upgrade button.
They omit benefits and current → resulting comparisons. Authored stage names are
not shown. Current benefits remain on the building detail screen.

Build cost/Upgrade cost shows large material artwork, names, and required amounts:
white when affordable, destructive red when insufficient. Do not show owned
balances; accessibility marks insufficient costs without announcing balances.
The offer fits its measured content, expands and scrolls when needed, and dismisses
by swiping down. It has no Close button, empty navigation bar, summary disclosure,
info sheet, or future-tier browser.

## Purchases and feedback

Purchases validate the displayed tier and save immediately. Transient save/cloud
failures retain the action for silent retry under the
[storage contract](../AgentContext/persistence-storage.md); domain rejections retain
their existing feedback. Success closes the offer, then fills the newly earned
segment left-to-right with a spring, followed by numeric transitions and brief gold
emphasis on changed bonuses and increased production. Labels and material artwork
stay still. Hold the previous presentation values until dismissal; animation never
commits progress. Backgrounding or navigation suppresses pending celebration.

## Material collection

Available materials appear above Collect as centered, non-overlapping icons in
wallet order: one row when it fits, otherwise rows of at most four. A staggered
bounce with a rest between passes draws attention without moving surrounding
layout. It runs only while the overview and preview are visible, the app is active,
and collection is available; it has no sound or haptics.

Collect saves first, captures the moving artwork's visible anchors, then gathers
and deposits it into the matching wallet artwork in staggered wallet order.
Displayed totals and their small bumps update on arrival; destination artwork
stays still. The first landing gives one success haptic when enabled. Retain the
collection row's height through transfer, then settle it away after the last landing.

Presentation never grants rewards. Leaving Homestead, backgrounding, or changing
flight geometry cancels the effect and reveals saved balances. Missing or offscreen
endpoints skip travel. Transient save/cloud failures retry silently without success
feedback until committed; other domain outcomes retain their existing feedback.

## Artwork

Portrait and landscape sources coexist in the Asset Library's building subject folders.
[ArtManifest](../../ArtManifest/README.md) owns portrait and gallery-thumbnail
exports. Gallery thumbnails join launch-priority artwork. Full portraits remain
outside broad launch warmup and are pinned by imminent category/detail owners.
Preserve existing pins and memory limits.

## Bonus and production rules

Each building has four tiers. Every numeric bonus and each material output
increases at every tier; tier values replace lower tiers. Crystal Garden grants
percentage Critical damage and produces both Gems and Stone. Library and Agility
Training intentionally have no production. All material types have a producer.

Descriptions use the same player-directed voice as affixes: Increase, Take,
Restore, Gain, Find, and Produce. They have no trailing periods. Hero and Companion
scopes remain explicit where they differ. Full-width descriptions target one line
at 393-point portrait width and the default text size; smaller screens and larger
text sizes retain natural wrapping. Production remains an absolute quantity per Day
and uses the existing clock; collecting multiple resources preserves each resource's
fractional production independently. Multiple outputs remain individual rows.

Homestead bonuses replace lower tiers. Maximum Hero and Companion Health use
10/20/30/40%; damage-type bonuses use 10/15/20/25%; Critical damage, Health restored,
Block gained, and Mana restored use 10/20/30/40%. Leech healing, Companion damage,
ranged damage, and typed resistance use 5/10/15/20%. Dodge remains an additive
2/4/6/8 percentage-point Companion chance bonus. Damage-type, Companion, and ranged
bonuses add before rounding; the Critical bonus multiplies the existing Critical
result separately. Ranged bonuses retain the equipped Bow/Crossbow Physical-damage
scope. Burn/Poison's stored potency is not scaled again on later ticks. General
restoration and Leech-specific bonuses each apply once to Leech healing; the
Leech percentage includes flat equipment and conditional Leech healing bonuses. Resolved
Block transfers do not repeat gain bonuses. No percentage grants a minimum +1.

Library increases earned Experience by 5/10/15/20%, added to other XP percentages
before existing recipient caps. Wishing Well increases positive earned Gold and
Moonlit Sanctum increases existing Gem rewards by 5/10/15/20%. Neither changes
production, purchase refunds, or initial balances; the Gem bonus cannot create Gems
in rewards without Gems. Unpaid Gold/Gem hundredths persist separately from production,
so repeated small rewards eventually pay their full percentage. Pure previews do not
consume those fractions; settlement captures them and claim advances them atomically.
Mystery offers pin their reward basis and refresh fractional payouts without rerolling
the item. Older pinned offers remain claimable. Reward previews and settlement share
these adjustments, including overridden battle loot. Existing tiers, save identifiers,
and flat equipment modifier cases remain readable.

Upgrade costs are fixed authored values. Their material proportions account for
production support and total upgrade demand; prices do not depend on which
buildings the player owns.

## Blacksmith crafting

A built Blacksmith exposes a separate anvil **Craft** row above its Upgrade
section and static benefits panel. Action rows and static benefits share the same
thin material. Action text uses the same row-title typography as
benefit headers. Craft opens a native sheet at
medium height over the Blacksmith, keeping the building's identity visible.
Its opaque semantic surface separates Inventory-sized, two-column recipe artwork
from the building artwork. The sheet can be expanded by dragging and dismissed by swiping down. It has no
Resources or Close toolbar buttons; balances remain accessible on the node screen.

The recipe order is Dagger, Shortsword, Longsword, Greatsword, Hatchet, Double Axe,
Mace, Flail, Maul, Kite Shield, and Plate Armor. All unlock at Blacksmith tier one.
Dagger, Shortsword, and Hatchet cost 24 Iron + 12 Wood; Longsword, Mace, Flail,
and Kite Shield cost 32 Iron + 16 Wood; Greatsword, Double Axe, and Maul cost
40 Iron + 20 Wood; Plate Armor costs 40 Iron + 20 Hide. These fixed initial prices
preserve a net material sink when ordinary forged gear is salvaged.

Selecting a base immediately uses ordinary navigation inside that same sheet, with a compact
520-point working detent for its artwork/name, material cost, and Forge button.
The prepared thumbnail appears while the full artwork finishes preparing; artwork
readiness does not delay the Forge button.
Selecting a recipe always fits the preview to that working detent, even after
browsing at large height. Artwork and costs stay grouped at the top if the preview
is expanded manually. Returning to the grid restores its chosen browsing height.
Forge scroll views use the native soft top scroll-edge effect. Recipe selection
never zooms an artwork into a different layout. The preview has no predicted
rarity, powers, or explanatory copy.

After commitment and artwork preparation, the result replaces the source artwork
in place, without removing or sliding the card. A native source-linked zoom opens
the actual Item detail in the same navigation stack while the sheet expands to
large. **Added to Inventory** appears below the item name on the hero art; one success
haptic accompanies the first visible reveal.
Back returns to the saved result card, which can reopen details without another
craft or success haptic. Swiping down returns to the Blacksmith. Interrupted or
backgrounded preparation retains the item without launching a late detail view;
the saved result card retains Done for this recovery path.

Forging uses the shared non-boss item generator at the highest won encounter level.
Blacksmith tiers 2–4 add a forge-only Astral tier-weight bonus of 10%, 20%, and
30% respectively, shown with the Blacksmith's benefits. Basic and Astral outcomes retain normal
rolls. Unique outcomes use only the chosen base's authored, unowned Unique;
Trinkets never appear. Removing unavailable categories renormalizes loot weights.
Building upgrades do not change recipes or prices.

Material spending and inventory insertion commit atomically before success is
presented. Transient retries retain the same rolled candidate. Leaving the flow
never loses an accepted item, and reveal animation never grants one. Native
navigation, Inventory's item detail presentation, prepared artwork, and existing
motion/haptic preferences govern presentation.
