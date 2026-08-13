# Homestead UX

Player-facing Homestead layout. Implementation lives in `Trinket/Features/Homestead/`.

- Art-led overview: full-bleed hero, compact eight-resource wallet, and Play Mode–style category cards (Farming / Crafting / Alchemy / Training / Arcana) with tier-sum constructed progress — tapping a category pushes its project list.
- Category list keeps hero (category art) + wallet, drops the in-content category header, and lists that category’s projects; project rows stay tappable in every state (including prerequisite-locked) and push native `NavigationStack` detail while retaining the tab bar.
- Detail shows a single vertical tier path plus a persistent build/upgrade footer; build/upgrade is immediate with no confirmation dialog (PD-012).
- Dense content stays on solid semantic surfaces; keep glass/material for floating chrome and the detail footer.
