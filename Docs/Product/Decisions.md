# Product decisions

Stable product decisions that guide implementation. Keep entries concise and update a decision only when the product direction changes.

| ID | Decision | Implementation consequence |
|---|---|---|
| PD-001 | Battle is an execution surface, not a pre-battle configuration wizard. | Do not add a setup funnel before battle. |
| PD-002 | Hero and companion loadouts live in their collection detail/drill-in surfaces. | Keep configuration roster-owned and reachable from Collection. |
| PD-003 | Collection prioritizes overview plus drill-ins. | Keep top-level browsing scannable; put detailed changes behind navigation. |
| PD-004 | Equipment is configured from Collection and its resolved build affects combat. | Keep loadout editing roster-owned; bake equipment and affix effects into the battle launch rather than reading live inventory from Battle. |
| PD-005 | Locked UI keeps its structure visible and communicates unavailable gameplay actions. | Disable unavailable gameplay actions; inspection and purchase entry follow the surface's product contract, including [Monetization.md](Monetization.md). Do not remove the locked layout. |
| PD-006 | Native iOS behavior is the default. | Prefer first-party SwiftUI over custom compatibility layers. |
| PD-007 | Superseded by PD-014. | Retained for decision history. |
| PD-008 | Identity unlocks cross-device progress only. | iCloud private CloudKit is the sync mechanism; do not add an in-app account. |
| PD-009 | Play is always available without login or iCloud. | No login splash, SIWA, Google, Game Center, or “save progress?” prompts. |
| PD-010 | No iCloud on device means full local play. | Progress stays on device; never block on identity or sync errors. |
| PD-011 | Sign in with Apple, Google, and hosted accounts are out of scope. | Do not add account rows, OAuth, or a user directory. See [Identity.md](Identity.md). |
| PD-012 | Homestead build/upgrade is immediate. | No confirmation dialog; the offer sheet’s Build/Upgrade action buys the displayed affordable stage immediately. See [Homestead.md](Homestead.md). |
| PD-013 | Talent tree rows represent UI visual unlock progression only. | All talent nodes share an equivalent flat power budget; do not scale talent magnitude by row or tier. |
| PD-014 | Trinket is visual-first with explicit basic accessibility semantics. | Every SwiftUI image is labeled or hidden from accessibility, and stable `accessibilityIdentifier` values remain available to UI tests. Do not add bespoke accessibility modes, setting-specific layout branches, or accessibility-setting UI tests. |
| PD-015 | Superseded by PD-019. | Retained for decision history. |
| PD-016 | Advancing through content must retain increasing difficulty when players change parties. | Campaign uses bounded downward adjustment, Spires use fixed floor levels, and Labyrinth uses rising depth minimums. Exact tuning requires balance verification. |
| PD-017 | Keep the existing roster catch-up XP mechanic. | Preserve role-specific catch-up against the highest hero or companion level when revising encounter scaling and adding leveling opportunities. |
| PD-018 | Character levels and level-driven enemy power have no designed upper cap or terminal plateau. | Replace the enemy power plateau after level 40 with continuing growth; retain numeric safety and mechanic-specific probability limits. Finite content still ends. |
| PD-019 | Campaign and Spires retain permanent completion without replays; Labyrinth continues through infinite floors. | Preserve saved completion and explored Labyrinth maps; no terminal Labyrinth depth is required. |
| PD-020 | Superseded by PD-021. | Retained for decision history. |
| PD-021 | Contracts provides unlimited renewable single-battle jobs for any party from the start of Play. | [Contracts.md](Contracts.md) owns offer, difficulty, reward, lifecycle, and presentation rules. |
| PD-022 | Trinket is free to start with one permanent Full Game purchase. | [Monetization.md](Monetization.md) owns the free boundaries, purchase offer, earned progression, and future-content promise. |
| PD-023 | Talents are a finite character kit; levels continue beyond talent completion. | Keep one talent point at even levels, stop talent prompts and affordances when no legal node remains, and preserve uncapped Health, Mana, and level-driven enemy progression. |

These are product constraints, not a backlog. Sibling product docs:
[README.md](README.md). For source ownership and tests, read the relevant `Docs/AgentContext/` card.

Decision IDs are append-only. When direction changes, mark the prior decision as
superseded and add a new entry instead of silently rewriting history. Any
temporary decision must name the condition that should trigger review.
