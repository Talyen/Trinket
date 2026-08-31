# Product decisions

Stable product decisions that guide implementation. Keep entries concise and update a decision only when the product direction changes.

| ID | Decision | Implementation consequence |
|---|---|---|
| PD-001 | Battle is an execution surface, not a pre-battle configuration wizard. | Do not add a setup funnel before battle. |
| PD-002 | Hero and companion loadouts live in their collection detail/drill-in surfaces. | Keep configuration roster-owned and reachable from Collection. |
| PD-003 | Collection prioritizes overview plus drill-ins. | Keep top-level browsing scannable; put detailed changes behind navigation. |
| PD-004 | Equipment is configured from Collection and its resolved build affects combat. | Keep loadout editing roster-owned; bake equipment and affix effects into the battle launch rather than reading live inventory from Battle. |
| PD-005 | Locked UI keeps its structure visible and disables/mutes controls. | Do not replace locked controls with removed layout or a separate funnel. |
| PD-006 | Native iOS behavior is the default. | Prefer first-party SwiftUI over custom compatibility layers. |
| PD-007 | Trinket is visual-first and currently relies on native SwiftUI accessibility behavior. | Preserve native semantics and stable `accessibilityIdentifier` values used by UI tests. Do not add bespoke accessibility modes or setting-specific layout branches without an approved product requirement. No accessibility-setting UI tests. |
| PD-008 | Identity unlocks cross-device progress only. | iCloud private CloudKit is the sync mechanism; do not add an in-app account. |
| PD-009 | Play is always available without login or iCloud. | No login splash, SIWA, Google, Game Center, or “save progress?” prompts. |
| PD-010 | No iCloud on device means full local play. | Progress stays on device; never block on identity or sync errors. |
| PD-011 | Sign in with Apple, Google, and hosted accounts are out of scope. | Do not add account rows, OAuth, or a user directory. See [Identity.md](Identity.md). |
| PD-012 | Homestead build/upgrade is immediate. | No confirmation dialog; the action is the next affordable tier node. See [Homestead.md](Homestead.md). |
| PD-013 | Talent tree rows represent UI visual unlock progression only. | All talent nodes share an equivalent flat power budget; do not scale talent magnitude by row or tier. |

These are product constraints, not a backlog. For source ownership and tests, read the relevant `Docs/AgentContext/` card.

Decision IDs are append-only. When direction changes, mark the prior decision as
superseded and add a new entry instead of silently rewriting history. Any
temporary decision must name the condition that should trigger review.
