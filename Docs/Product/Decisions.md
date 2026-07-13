# Product decisions

Stable product decisions that guide implementation. Keep entries concise and update a decision only when the product direction changes.

| ID | Decision | Implementation consequence |
|---|---|---|
| PD-001 | Battle is an execution surface, not a pre-battle configuration wizard. | Do not add a setup funnel before battle. |
| PD-002 | Hero and companion loadouts live in their collection detail/drill-in surfaces. | Keep configuration roster-owned and reachable from Collection. |
| PD-003 | Collection prioritizes overview plus drill-ins. | Keep top-level browsing scannable; put detailed changes behind navigation. |
| PD-004 | Item/equipment presentation is visual-only until gameplay effects are explicitly requested. | Do not wire inventory/equipment values into combat rules as incidental work. |
| PD-005 | Locked UI keeps its structure visible and disables/mutes controls. | Do not replace locked controls with removed layout or a separate funnel. |
| PD-006 | Native iOS behavior is the default. | Prefer first-party SwiftUI and accessibility fallbacks over custom compatibility layers. |
| PD-007 | Trinket is visual-first with minimal accessibility support. | Keep native SwiftUI control behavior and stable UI-test identifiers; do not add custom VoiceOver semantics, accessibility-setting branches, accessibility audits, or accessibility-specific art metadata. Full VoiceOver, Dynamic Type adaptation, reduced-motion/transparency, contrast, and other comprehensive accessibility support are out of scope. |

These are product constraints, not a backlog. For source ownership and tests, read the relevant `Docs/AgentContext/` card.
