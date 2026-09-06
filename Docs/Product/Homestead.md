# Homestead UX

Player-facing Homestead layout. Implementation lives in `Trinket/Features/Homestead/`.
Locked rule is PD-012 in [Decisions.md](Decisions.md): build/upgrade is
immediate, no confirmation dialog.

- Art-led overview: full-bleed hero, compact eight-resource wallet, and Play Mode–style category cards (Farming / Crafting / Alchemy / Training / Arcana) with tier-sum constructed progress — tapping a category pushes its project list.
- Category list keeps hero (category art) + wallet, drops the in-content category header, and lists that category’s projects; project rows stay tappable in every state (including prerequisite-locked) and push native `NavigationStack` detail while retaining the tab bar.
- Detail shows a single vertical tier path; build/upgrade happens on the next affordable tier node with no confirmation dialog (PD-012).
- Dense content stays on solid semantic surfaces; keep glass/material for floating chrome.
- Locked controls keep their structure visible and disabled/muted per PD-005; do not replace them with a separate funnel.

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
