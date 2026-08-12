# Product decisions

Stable product decisions that guide implementation. Keep entries concise and update a decision only when the product direction changes.

| ID | Decision | Implementation consequence |
|---|---|---|
| PD-001 | Battle is an execution surface, not a pre-battle configuration wizard. | Do not add a setup funnel before battle. |
| PD-002 | Hero and companion loadouts live in their collection detail/drill-in surfaces. | Keep configuration roster-owned and reachable from Collection. |
| PD-003 | Collection prioritizes overview plus drill-ins. | Keep top-level browsing scannable; put detailed changes behind navigation. |
| PD-004 | Equipment is configured from Collection and its resolved build affects combat. | Keep loadout editing roster-owned; bake equipment and affix effects into the battle launch rather than reading live inventory from Battle. |
| PD-005 | Locked UI keeps its structure visible and disables/mutes controls. | Do not replace locked controls with removed layout or a separate funnel. |
| PD-006 | Native iOS behavior is the default. | Prefer first-party SwiftUI and accessibility fallbacks over custom compatibility layers. |
| PD-007 | Trinket is visual-first and supports a practical native accessibility baseline. | Preserve native semantics; label custom interactive controls; support Dynamic Type on navigation, settings, and reading surfaces; centralize reduced-motion/transparency behavior; and never convey essential state through color, sound, or motion alone. Prefer focused Accessibility Inspector review over a combinatorial UI-test matrix. |
| PD-008 | Identity unlocks cross-device progress only. | iCloud private CloudKit is the sync mechanism; do not add an in-app account. |
| PD-009 | Play is always available without login or iCloud. | No login splash, SIWA, Google, Game Center, or “save progress?” prompts. |
| PD-010 | No iCloud on device means full local play. | Progress stays on device; never block on identity or sync errors. |
| PD-011 | Sign in with Apple, Google, and hosted accounts are out of scope. | Do not add account rows, OAuth, or a user directory. See [Identity.md](Identity.md). |
| PD-012 | Homestead build/upgrade is immediate. | No confirmation dialog; keep the persistent footer action. See [Homestead.md](Homestead.md). |

These are product constraints, not a backlog. For source ownership and tests, read the relevant `Docs/AgentContext/` card.
