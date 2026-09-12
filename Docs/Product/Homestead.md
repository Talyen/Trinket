# Homestead UX

Player-facing Homestead layout. Implementation and presentation tuning live in
`Trinket/Features/Homestead/`. [PD-012](Decisions.md) owns immediate purchases
without a confirmation dialog.

## Browsing and benefits

The overview keeps its full-bleed landscape hero, compact eight-resource wallet,
and Play Mode–style category cards: Farming, Crafting, Alchemy, Training, Arcana.
Cards show tier-sum constructed progress and push stable two-column portrait
building galleries. Buildings retain their names and thin borders; affordable
improvements get a soft stationary gold halo. Prerequisite-locked buildings
remain inspectable. Galleries expose balances through Resources, without a
persistent wallet or repeated category hero. Segmented progression appears only
on building details.

Building details use full-screen portrait artwork, the building name, segmented
progress, and native gold Back/Resources toolbar controls matching the gallery.
Only building details hide the tab bar. Resources opens a compact expandable
wallet sheet with a Close control.

A compact native glass bottom panel shows exact current benefits with standard
bold/color keywords and white values. Bonus and Production headings share a
baseline, with top-aligned content in separate columns. Production sits on the
right with large material artwork, its name, and a white daily rate in wallet
style. Details and offers share this layout. Completed buildings keep benefits
and omit Build/Improve. Progress uses the catalog's actual tier count; descriptions
wrap and panel content scrolls as needed. No persistent completion banner,
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

Purchases validate the displayed tier and save immediately. Failed saves retain
the existing error handling. Success closes the offer, then fills the newly earned
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
endpoints skip travel. Preserve collection-error alerts and feedback.

## Artwork

Portrait and landscape sources coexist in `Raw Assets/Homestead/`.
[ArtManifest](../../ArtManifest/README.md) owns portrait and gallery-thumbnail
exports. Gallery thumbnails join launch-priority artwork. Full portraits remain
outside broad launch warmup and are pinned by imminent category/detail owners.
Preserve existing pins and memory limits.
