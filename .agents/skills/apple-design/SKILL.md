---
name: apple-design
description: Design or review Trinket SwiftUI layout, gestures, motion, typography, materials, feedback, and player-facing copy. Use for visual or interaction changes, including localized UI defects; skip logic-only refactors.
---

# Design the player interaction

Follow [clarity through layout](../../../Docs/Product/DesignPrinciples.md#clarity-through-layout):
avoid taglines, helper text, and secondary labels—if a screen needs them to make
sense, improve the layout instead.

Start from the player's action and the state they need to understand, and reuse
[TrinketDesignSystem](../../../Packages/TrinketDesignSystem/README.md) controls,
roles, and motion recipes where they fit. Scale the design pass to the task: a
localized fix can rely on existing screenshots or source context without turning
into a redesign, while visual composition and polish work benefit from
[Foundations and process](foundations-and-process.md) and optional
[visual inspection](../../../Docs/Platform/Verification.md#visual-inspection).

Load the references relevant to the change:

| Concern | Reference |
| --- | --- |
| Gesture response, cancellation, interruption, settling | [Motion and gestures](motion-and-gestures.md) |
| Glass, scrims, overlays, legibility | [Materials and depth](materials-and-depth.md) |
| Text hierarchy and fit | [Typography](typography.md) |
| Labels, recovery copy, contextual teaching | [Writing and help](writing-and-help.md) |
| Responsiveness, sound, haptics | [Performance and feedback](performance-and-feedback.md) |
| Screen critique, a new flow, or substantial redesign | [Foundations and process](foundations-and-process.md) |

Related guidance:
- [SwiftUI feature context](../../../Docs/AgentContext/swiftui-features.md) for feature integration contracts.
- [swiftui-specialist](../swiftui-specialist/SKILL.md) for SwiftUI state, identity, view structure, or update behavior, and [swiftui-whats-new-27](../swiftui-whats-new-27/SKILL.md) for SDK 27 migration or new APIs.
- [Platform support](../../../Docs/Platform/ApplePlatformReference.md#platform-support) for current iOS API adoption (the deployment target is a minimum, not a ceiling).
- [PD-014](../../../Docs/Product/Decisions.md) for accessibility scope, image semantics, and stable test identifiers.
- [Verification.md](../../../Docs/Platform/Verification.md#choosing-ui-verification), [ios-simulator](../ios-simulator/SKILL.md), and [Testing.md](../../../Docs/Platform/Testing.md) for visual inspection and test coverage.
