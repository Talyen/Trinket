# ImageGen prompts

## Library and Research (v4)

Retained prompts for the selected concepts; inputs and implementation corrections
live in [Mockups.md](Mockups.md). These use existing artwork only. The Research
detail prompts retain a subsequently rejected **Where to find** row: omit it in
shipping UI under [Library](../Library.md#research). Earlier prompts remain in Git history.

### Library / Bestiary

```text
Use case: ui-mockup. Edit image1 (existing proposed Trinket Library/Bestiary two-screen board). Image2 actual game Forge screenshot is the native design reference; images3/4 are original existing LANDSCAPE Slime/Goblin paintings. Keep the entire LEFT Library building screen unchanged. Two complete upright screens side by side, near-black board, tiny external caption "PROPOSED UI - EXISTING ART".
On RIGHT keep native back and "Bestiary" title. Show a single vertical scrolling column of the two existing landscape enemy paintings. CRITICAL: remove ALL text labels below or over enemies: no Slime, Goblin, Defeated, Encountered, Undiscovered, no badges, checkmarks, arrows, status labels, overlays, borders or captions. Art ONLY. First is full-color Slime; second is fully grayscale Goblin, same treatment applied to whole painting. Their original source width:height is1200:896, approximately4:3; preserve this landscape ratio and complete scene, NEVER portrait, square or16:9. Art should fill available content width with native margins, modest rounded corners and a small12pt vertical gap. A portion can continue below viewport: don't squash images to fit. Grayscale enemy is disabled; do not add visual controls suggesting it can be tapped. Color enemy opens existing combatant detail sheet, but do NOT show a new invented sheet in this board. No filters, legend, text explanations, grouped unknowns or counters. Existing Library art, activity rows Bestiary/Research, Upgrade, tier indicator and XP benefit remain exactly as supplied. No new art.
```

### Research browser

```text
Use case: ui-mockup. Create ONE polished portrait iPhone Research browser screen in Trinket, no phone hardware. Image1 actual game Collection screenshot is the authority for real dark surfaces, native typography and art presentation; IGNORE simulator overlay. Images2/3/4 are EXISTING Shortbow, Longbow, Crossbow portrait paintings; preserve these exact items and compositions. This is a UI concept using only existing art, small exterior caption "PROPOSED UI - EXISTING ART".
Make Research feel lighter and more visual than a wall of text. Opaque near-black background, native gold Back, restrained system title "Research", comfortable native-sized type. Under small "In Progress" heading show THREE compact illustrated project rows. Each row has a SMALL72x96pt, STRICT3:4 PORTRAIT reward image on left, useful text in middle, one quiet native chevron on right. First existing Shortbow: title "Forest Field Notes", single smaller secondary line "Poison Shortbow"; progress below as THREE small native circles, first2 checked, last hollow, no fraction or explanatory sentence. Second existing Longbow: "Predator Anatomy", secondary "Bleed Longbow", same2 checked1 hollow. Third existing Crossbow: "Arms and Armor", secondary "Physical Crossbow", three hollow circles. Portraits are NOT large hero cards and NOT square icons; each clearly taller than wide. Rows share one quiet grouping with subtle separators, NO gold borders or separate nested panels. Keep row height about112pt. No objective lists here.
Below small "Completed" heading show TWO simple compact text rows: "Companion Chronicles" and "Spire Records", each small native checkmark and chevron, no duplicated "Archive record" subtitles, no illustrations or fake books. All5projects can fit a normal tall phone with scrolling at large text. Do not enlarge text to fill canvas or create huge empty gaps. No filter, global counter, repeated recipe/Archive labels, research currency, dashboard, progressbars, filler text or giant Library hero. Portrait items and modest whitespace supply visual rhythm, native hierarchy stays calm. No invented artwork. Every equipment image MUST be3:4portrait.
```

### Research detail

```text
Use case: ui-mockup. Create ONE polished portrait iPhone Research project-detail screen for Trinket using ONLY supplied existing artwork. Image1 actual Collection screenshot establishes opaque near-black surface, native iOS typography and restrained gold navigation; ignore its simulator overlay. Image2 existing Shortbow portrait master; images3/4/5 existing LANDSCAPE Slime, Goblin and The Blight Treant enemy paintings.
Native gold Back, quiet native navigation title "Forest Field Notes" (wrap gracefully if needed). No Library painting, flavor paragraph, progress fraction, large Reward heading or long text list.
Upper content shows a moderately sized existing Shortbow painting, STRICT3:4portrait around126pt wide x168pt tall, centered. Directly beneath one modest tappable native reward label "Poison Shortbow" with small chevron. No second View Recipe button, no workshop subtitle, no guarantee paragraph. This artwork/reward group opens read-only recipe preview. Don't make the image huge.
Below use ONE small heading "Defeat", then an adaptive strip of EXACTLY THREE compact objective cards side by side on ordinary phone width. Each uses existing enemy painting in LANDSCAPE about4:3 with its full composition (NOT portrait). Labels BELOW images: "Slime", "Goblin", "The Blight Treant" (last wraps2lines). Small native checked circles on first2, hollow circle on third. ALL THREE enemy paintings are IN COLOR: all3have been encountered, only first2defeated. Gray must never mean defeated or objective-incomplete. No numeric stats or new art. Cards have NO decorative background boxes, borders, glows or gold frames. At larger text they would wrap naturally, not shrink labels. Under the three cards allow ONE subtle native disclosure row "Where to find" with chevron, collapsed, no source paragraphs shown.
This is the complete detail: title -> portrait reward -> three visual defeat objectives -> quiet optional source disclosure. Preserve ample quiet space below without filler. Status is in the tiny checkmarks, not extra sentences. No buttons to accept/claim, timers, currencies, stats, badges, ornamental scrolls or new equipment. Native dark safe areas, legible restrained type, small external caption "PROPOSED UI - EXISTING ART".
```

### Research detail proportions correction

```text
Use case: ui-mockup. Make a precise layout polish edit to image1, the proposed Forest Field Notes Research detail. Image2 is actual Trinket Collection UI for native screenshot presentation. Images3/4/5 are original LANDSCAPE Slime/Goblin/The Blight Treant art. Preserve all text, objective check states, actual item and enemy art identity, near-black surface and quiet native gold navigation.
Change ONLY the following layout details:
1. Remove the illustrated physical phone hardware/frame and exterior perspective; present a flat upright native screen like image2. Keep ordinary safe areas. A tiny exterior concept caption is allowed.
2. The existing Shortbow reward portrait is too large. Reduce it by about25percent to a modest126pt wide x168pt tall, keeping EXACT3:4portrait. Center it under the native Forest Field Notes nav title. Keep its one tappable Poison Shortbow label and chevron directly below. Do not add prose.
3. All THREE objective images must have the original 4:3 LANDSCAPE aspect ratio, about94pt wide x70pt tall, preserving full original wide source composition. Currently they are too square. Use supplied original enemy scenes. Keep one strip3columns with names/checks BELOW the images, first2checked, Treant unchecked, all3images original COLOR. Names may wrap2lines.
Keep the Defeat heading, Where to find collapsed row, native Back, exact title and existing calm spacing. The screen should feel compact, elegant and illustrated without a huge item hero or text paragraphs. No new images, stats, rows, objective labels, controls or materials. Do not distort art to fit. Item stays PORTRAIT; enemies LANDSCAPE.
```

## Archery (v3)

```text
Use case: ui-mockup. Edit existing two-screen Trinket Archery concept image1. Image2 actual Forge screenshot is authoritative native crafting sheet and portrait item display. Image3 is the existing Shortbow portrait master. Preserve existing Archery Range painting, native Back and add existing Resources bag top-right to BOTH building screens. Maintain serif building title, near-black native sheet, system typography, safe-area costs dock, exact recipe and cost names. No new illustrations.
Critical correction: ALL equipment artwork, in recipe grids, reward/recipe row thumbnails and central preview, MUST be 3:4 PORTRAIT rectangles, visibly taller than wide. NO square thumbnails, NO landscape equipment cards, no squashing or rotating art. Use existing Shortbow and Longbow paintings already in image1.
LEFT: Show the Craft sheet expanded enough for a clean scrollable browser excerpt. "Standard Recipes" followed by TWO columns: a 3:4 portrait Shortbow card and a 3:4 portrait Longbow card, names below. They can be around120pt wide x160pt tall to fit elegantly. End viewport as next standard recipe row naturally begins or leave it below scroll; do NOT jump past missing standard recipes to Focused Recipes. No need to squeeze all five recipes into screenshot. No down arrows or explanatory labels. Browser must preserve portrait proportions rather than compress every artwork to show more rows.
RIGHT: Native sheet grabber; sheet navigation bar includes its OWN circular Back button and centered "Craft". Show central existing Shortbow in strict 3:4 PORTRAIT frame, approx174pt wide x232pt tall; below "Poison Shortbow", green secondary "Poison affix guaranteed", muted "Basic or Astral". Dock costs "Wood 48", "Iron 24", "Herbs 8", using existing resource icon style. One emphasized gold native full-width "Craft" button, safe area below. Preserve original artwork identity from image3 and resource icons. Quiet typography and minimal surfaces, no borders around every row, no extra actions or ornaments. Board small caption "PROPOSED UI - EXISTING ART". Two complete upright screens without hardware, enough vertical canvas to keep art portrait and controls unclipped.
```
