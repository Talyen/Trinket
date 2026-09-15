---
name: apple-design
description: Design or review Trinket SwiftUI layout, gestures, motion, typography, materials, feedback, and player-facing copy. Use for visual or interaction changes, including localized UI defects; skip logic-only refactors.
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
| Labels, recovery copy, contextual teaching | [Writing and help](writing-and-help.md) |
| Responsiveness, sound, haptics | [Performance and feedback](performance-and-feedback.md) |
| Screen critique or a new flow | [Foundations and process](foundations-and-process.md) |

[SwiftUI feature context](../../../Docs/AgentContext/swiftui-features.md) owns
feature integration rules. Use [swiftui-specialist](../swiftui-specialist/SKILL.md)
when the change involves SwiftUI state, identity, view structure, or update behavior;
use [swiftui-whats-new-27](../swiftui-whats-new-27/SKILL.md) for SDK 27 migration
or new APIs. Load only the technical reference relevant to the design change.
[Platform support](../../../Docs/Platform/ApplePlatformReference.md#platform-support)
owns adoption of current iOS APIs; the deployment target is a minimum, not a ceiling.
[PD-014](../../../Docs/Product/Decisions.md)
owns accessibility scope; retain existing accommodation behavior and use explicit
image semantics and stable test identifiers as specified by those owners.

Verification scope and completion follow
[Verification.md](../../../Docs/Platform/Verification.md#choosing-ui-verification).
Use the simulator skill when visual inspection is needed and
[Testing.md](../../../Docs/Platform/Testing.md) to choose test coverage.
