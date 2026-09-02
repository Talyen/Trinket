# Homestead UX

Player-facing Homestead layout. Implementation lives in `Trinket/Features/Homestead/`.
Locked rule is PD-012 in [Decisions.md](Decisions.md): build/upgrade is
immediate, no confirmation dialog.

- Art-led overview: full-bleed hero, compact eight-resource wallet, and Play Mode–style category cards (Farming / Crafting / Alchemy / Training / Arcana) with tier-sum constructed progress — tapping a category pushes its project list.
- Category list keeps hero (category art) + wallet, drops the in-content category header, and lists that category’s projects; project rows stay tappable in every state (including prerequisite-locked) and push native `NavigationStack` detail while retaining the tab bar.
- Detail shows a single vertical tier path; build/upgrade happens on the next affordable tier node with no confirmation dialog (PD-012).
- Dense content stays on solid semantic surfaces; keep glass/material for floating chrome.
- Locked controls keep their structure visible and disabled/muted per PD-005; do not replace them with a separate funnel.
