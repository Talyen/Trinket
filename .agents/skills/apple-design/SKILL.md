---
name: apple-design
description: Design or review Trinket SwiftUI layout, gestures, motion, typography, materials, and feedback. Use for visual or interaction changes, including localized UI defects; skip logic-only refactors.
---

# Design the player interaction

Start with the player's action and the state they need to understand. Reuse
[TrinketDesignSystem](../../../Packages/TrinketDesignSystem/README.md) controls,
roles, and motion recipes. For a localized fix, apply only guidance relevant to
the requested change. Existing screenshots or source context may be sufficient
to understand the current design; a separate baseline simulator session is not
mandatory. A local UI fix can need design judgment without becoming a redesign.

Read only references relevant to the change:

| Concern | Reference |
| --- | --- |
| Gesture response, cancellation, interruption, settling | [Motion and gestures](motion-and-gestures.md) |
| Glass, scrims, overlays, legibility | [Materials and depth](materials-and-depth.md) |
| Text hierarchy and fit | [Typography](typography.md) |
| Responsiveness, sound, haptics | [Performance and feedback](performance-and-feedback.md) |
| Screen critique or a new flow | [Foundations and process](foundations-and-process.md) |

[SwiftUI feature context](../../../Docs/AgentContext/swiftui-features.md) owns
platform and feature integration rules. [PD-014](../../../Docs/Product/Decisions.md)
owns accessibility scope; retain existing accommodation behavior and use explicit
image semantics and stable test identifiers as specified by those owners.

Verification scope and completion follow
[Verification.md](../../../Docs/Platform/Verification.md#choosing-ui-verification).
Use the simulator skill when visual inspection is needed and
[Testing.md](../../../Docs/Platform/Testing.md) to choose test coverage.
