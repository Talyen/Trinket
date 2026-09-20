# Homestead UX

Player-facing Homestead layout. Implementation and presentation tuning live in
`Trinket/Features/Homestead/`. [PD-012](Decisions.md) owns immediate purchases
without a confirmation dialog.

## Browsing and benefits

The overview keeps its full-bleed landscape hero, compact eight-resource wallet,
and Play Mode–style category cards: Farming, Crafting, Alchemy, Training, Arcana.
Cards show tier-sum constructed progress and push stable two-column portrait
building galleries. Buildings have centered names beneath their portraits and centered, 132-point-wide
upgrade segments between each portrait and name. Segment width is capped by the
tile width; fills use saved progress and the catalog tier count, including empty
segments for locked or unbuilt buildings. Buildings retain thin borders; affordable
improvements get a soft stationary gold halo. Prerequisite-locked buildings
remain inspectable. Galleries expose balances through Resources, without a
persistent wallet or repeated category hero. Returning from an upgrade refreshes
gallery segments without replaying the detail celebration.

Building details use full-screen portrait artwork, the building name, segmented
progress, and native gold Back/Resources toolbar controls matching the gallery.
Only building details hide the tab bar. Resources opens a compact expandable
wallet sheet with a Close control.

A compact native glass bottom panel shows exact current benefits. Each effect uses
an icon in a shared 28-point frame beside a secondary eyebrow and a body-sized
effect line. Icons and text blocks align at the top so wrapped descriptions keep
the icons, eyebrows, and first lines aligned. Bonuses use colored SF Symbols and
a Bonus eyebrow; production uses illustrated material artwork with the
resource name and a daily rate, without separate section headers. Effect labels
and bold white values stay tightly grouped; existing keyword formatting remains.
Details and offers share this layout. Bonus-plus-production items use equal-width
columns when both natural widths fit, otherwise full-width stacked items. Bonus-only
buildings stack one full-width item per effect. Descriptions wrap without truncating
values or comparisons, and panel content scrolls as needed. Completed buildings
keep benefits and omit Build/Improve.

Bonus symbols reuse keyword identities and colors: Health uses heart.fill; healing
uses heart.circle.fill; damage uses its keyword symbol; damage resistance uses
shield.fill tinted to its keyword. Party protection uses Block styling; companion
damage uses pawprint.fill with Physical tint; ranged damage uses figure.archery with
Physical tint; Dodge uses wind; Astral finds uses sparkles with arcane tint; Gold finds
uses circle.circle.fill with Gold tint.
Production uses the same illustrated resource artwork as wallets, collection,
and purchase costs for every material.
Progress uses the catalog's actual tier count. No persistent completion banner,
checkmark, or Tier N label appears.

## Next-stage offers

Build/Improve opens the next-stage offer. Titles use **Build {building name}**
for the first tier and **Upgrade {building name}** thereafter, never authored
stage names. Changed existing benefits and production show current → resulting
values; initial builds and newly introduced benefits show resulting values only.

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

Portrait and landscape sources coexist in `Raw Assets/Homestead/`.
[ArtManifest](../../ArtManifest/README.md) owns portrait and gallery-thumbnail
exports. Gallery thumbnails join launch-priority artwork. Full portraits remain
outside broad launch warmup and are pinned by imminent category/detail owners.
Preserve existing pins and memory limits.

## Bonus and production rules

Each building has four tiers. Every numeric bonus and each material output
increases at every tier; tier values replace lower tiers. Crystal Garden grants
flat Critical damage and produces both Gems and Stone. Library and Agility
Training intentionally have no production. All material types have a producer.

Descriptions use concise labels and signed values: Health, Mana, Experience,
Physical damage, and Poison damage taken. Hero and Companion scopes remain
explicit where they differ. Production uses the existing daily clock and shows
per Day; collecting multiple resources preserves each resource's fractional
progress independently. Multiple outputs stack as individual benefit rows.

Critical damage and Mana restored modify existing outcomes without additional
combat-text events. Library adds flat Experience to earned reward awards;
Wishing Well adds flat Gold to positive earned Gold rewards. Neither changes
production, purchase refunds, or initial balances. Moonlit Sanctum adds its Gem
bonus once to encounter rewards that already contain Gems. Reward previews and
settlement share these adjustments, including overridden battle loot.

Upgrade costs are fixed authored values. Their material proportions account for
production support and total upgrade demand; prices do not depend on which
buildings the player owns.
