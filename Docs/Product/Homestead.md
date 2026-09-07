# Homestead UX

Player-facing Homestead layout. Implementation lives in `Trinket/Features/Homestead/`.
Locked rule is PD-012 in [Decisions.md](Decisions.md): build/upgrade is
immediate, no confirmation dialog.

- Art-led overview: full-bleed hero, compact eight-resource wallet, and Play Mode–style category cards (Farming / Crafting / Alchemy / Training / Arcana) with tier-sum constructed progress — tapping a category pushes its building gallery.
- Categories use stable two-column portrait galleries with building names; segmented progression appears only on full-art building screens. Affordable improvements get a restrained border; prerequisite-locked buildings remain inspectable. Balances are available from a resource control instead of a persistent wallet or repeated category hero.
- Building detail uses full-screen portrait artwork, circular Back/Resources controls, the building name and a segmented progress bar. The tab bar is hidden only inside a building.
- A compact solid bottom panel always shows concise, exact current benefits with standard bold/color keywords and white values. Material production sits to the right of the bonuses, top-aligned: large artwork, material name and a white daily rate in the wallet style. Unbuilt buildings explicitly label their first-build benefits; completed buildings keep their benefits and omit Build/Improve.
- Build/Improve opens the next-stage offer. The resulting next-stage effects appear immediately, with production on the right and a labeled Build cost/Upgrade cost section. Costs use large material artwork, names and white amounts; available balances appear only for shortages. The offer fits its measured content, expands and scrolls when needed, and dismisses by swiping down; it has no Close button or empty navigation bar. Wallet sheets retain their Close control. There is no summary disclosure, comparison, info sheet or future-tier browser.
- Purchases remain immediate and bound to the displayed tier. Failed saves retain the existing error handling. A successful purchase closes the sheet and briefly emphasizes the newly earned segment; animation never commits progress. Backgrounding/navigation suppresses pending celebration.
- Progression uses the catalog's actual tier count, including longer future paths. Descriptions wrap and panel content scrolls when needed. No persistent completion banner, checkmark or Tier N label is shown.

Portrait and landscape sources coexist in `Raw Assets/Homestead/`. The art pipeline
owns full portraits and dedicated 960-pixel gallery thumbnails; see
[ArtManifest](../../ArtManifest/README.md). Gallery thumbnails join launch-priority
artwork so category first paint is prepared. Full portraits remain outside broad
launch warmup and are pinned by imminent category/detail owners. Existing pins and
memory limits remain intact. The overview retains its landscape sections and
collection flow.

## Material collection

Collect saves the available materials immediately, then presents a compact deposit:
the preview artwork gathers for 90 ms and travels into the matching wallet artwork
over 340 ms, staggered by 25 ms in wallet order. Displayed totals and their small
bumps update on arrival; destination artwork stays still. The first landing gives
one success haptic when enabled. The collection row retains its height during the
transfer and settles away over 180 ms after the last landing. Available materials
receive one gentle attention cue, without a repeating idle bounce.

Presentation never grants rewards. Leaving Homestead, backgrounding, or changing
flight geometry cancels the effect and reveals saved balances. Missing or offscreen
endpoints skip travel. The existing collection-error alert and error-feedback wiring are retained.
