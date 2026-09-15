---
name: swiftui-specialist
description: Implement or review SwiftUI state, observation, environment, view identity, structure, animation, and localization using Apple's technical references. Use for correctness and performance work; player-facing design decisions also use apple-design.
---

# SwiftUI implementation

Read the reference for the behavior being changed. For a small fix, load only
the relevant topic or section; do not turn it into a general SwiftUI audit.
Apple's examples explain framework behavior. Apply them within the ownership
and product contracts in [SwiftUI feature context](../../../Docs/AgentContext/swiftui-features.md).

| Concern | Reference |
| --- | --- |
| View inputs, `@State`, `@Observable`, bindings, `onChange` dependencies | [Data flow](references/dataflow.md) |
| Custom environment actions, `@Entry` defaults, frequent environment updates | [Environment performance](references/environment.md) |
| Stable collection identity and efficient `ForEach` / `List` rows | [ForEach](references/foreach.md) |
| Separate view update boundaries, cheap initializers, single-child `Group` | [View structure](references/structure.md) |
| Conditional modifiers and `AnyShapeStyle` | [Modifiers](references/modifiers.md) |
| Custom `Animatable` implementations and macros | [Animations](references/animations.md) |
| Localizable text, package bundles, interpolation, formatting | [Localization](references/localization.md) |
| Choosing a replacement for a soft-deprecated API | [Migration scope](references/soft-deprecation.md), then search the [API catalog](references/soft-deprecated-apis.md) for that symbol |

For SDK 27 migration errors or new APIs, use
[swiftui-whats-new-27](../swiftui-whats-new-27/SKILL.md). For layout, gestures,
motion design, materials, typography, or player-facing copy, also use
[apple-design](../apple-design/SKILL.md).

A reference matching a code pattern is an investigation lead, not a measured
performance defect. Follow the affected inputs, identity, and lifecycle before
choosing a fix. Preserve the app's existing observation and resource owners;
do not introduce new model layers solely to reproduce a reference example.
Verification and performance claims follow
[Verification.md](../../../Docs/Platform/Verification.md).

Source version, local adaptations, and refresh procedure:
[Apple skill references](../../../Docs/Platform/ApplePlatformReference.md#apple-skill-references).
