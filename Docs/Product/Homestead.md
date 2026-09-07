# Homestead UX

Player-facing Homestead layout. Implementation lives in `Trinket/Features/Homestead/`.
Locked rule is PD-012 in [Decisions.md](Decisions.md): build/upgrade is
immediate, no confirmation dialog.

- Art-led overview: full-bleed hero, compact eight-resource wallet, and Play Mode–style category cards (Farming / Crafting / Alchemy / Training / Arcana) with tier-sum constructed progress — tapping a category pushes its project list.
- Category list keeps hero (category art) + wallet, drops the in-content category header, and lists that category’s projects; project rows stay tappable in every state (including prerequisite-locked) and push native `NavigationStack` detail while retaining the tab bar.
- Project-list indicators use a small tier marker and a consistent navigation chevron. Gold emphasis means the next stage is affordable; a filled marker marks a finished project. Prerequisite locks remain inspectable.
- Building detail uses its dedicated portrait artwork full-screen. Back returns to the category; the tab bar is hidden only inside a building. The name, tier/info control, resource pouch, and Build/Improve entry are the resting UI.
- Build/Improve opens a compact native offer sheet containing the next stage, concise benefit summary, material cost chips, and the immediate Build/Upgrade purchase. This is offer navigation, not a purchase confirmation. Expand the summary for exact current-to-next effects; All tiers opens passive, scrollable history in the sheet.
- Tier/info opens current benefits and history. The pouch opens read-only resource balances; material collection remains on the overview.
- Descriptions use standard bold/color keywords and resource chips. Exact effects are assembled from the typed combat bonus and production values, with no truncation or fixed row heights. Progression follows the catalog's tier count, including longer future paths.
- A successful saved purchase dismisses the offer and briefly settles the updated tier with one success haptic when enabled. Repeated input is bound to the displayed offer; animation never commits progress. Failed saves keep the offer and existing error handling. Backgrounding/navigation suppresses pending celebration.
- Completed buildings keep their tier/info and wallet controls, gain a restrained finishing ring, and omit Build/Improve. No persistent completion banner or checkmark.
- Unavailable purchases retain a disabled purchase control, visible costs, and an explanation of missing materials or prerequisite stages. Dense sheet content uses solid semantic surfaces; floating controls use shared glass chrome.

Portrait and landscape sources coexist in `Raw Assets/Homestead/`. The art pipeline
owns their separate exports and catalog references; see [ArtManifest](../../ArtManifest/README.md).
Portraits stay out of broad launch warmup. Category navigation prepares and pins imminent portraits as well as existing
landscape artwork. Both the category and detail release only their own pins when
leaving; decoded artwork budgets remain owned by the performance playbook.

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
