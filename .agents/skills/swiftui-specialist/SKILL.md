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
| View inputs | [Passing data](references/dataflow.md#passing-data-into-views) |
| `@State` and bindings | [Local state](references/dataflow.md#view-local-state-with-state), [Bindings](references/dataflow.md#bindings) |
| `@Observable` dependencies | [Property granularity](references/dataflow.md#per-property-dependency-granularity-on-observable-models), [Computed properties](references/dataflow.md#cache-derived-observable-values-computed-properties-still-establish-dependencies-transitively) |
| `onChange` dependencies | [Side effects](references/dataflow.md#isolating-onchangeof-side-effect-invalidation) |
| Custom environment actions | [Closures](references/environment.md#closures-in-the-environment) |
| `@Entry` defaults | [Unstable defaults](references/environment.md#unstable-environment-default-values) |
| Frequent environment updates | [Rapid updates](references/environment.md#rapidly-updating-environment-values) |
| Collection identity | [Avoid index identity](references/foreach.md#avoid-collection-indices-as-identity), [Identity lifetime](references/foreach.md#identity-must-outlive-the-view-that-renders-the-foreach) |
| Collection update cost | [Cheap IDs](references/foreach.md#keep-the-id-cheap-to-hash), [Sorting and filtering](references/foreach.md#dont-sort-or-filter-inline-in-foreach) |
| `List` row structure | [Unary rows](references/foreach.md#prefer-unary-row-views-in-list) |
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
[Verification.md](../../../Docs/Platform/Verification.md#choosing-ui-verification).

Source version, local adaptations, and refresh procedure:
[Apple skill references](../../../Docs/Platform/ApplePlatformReference.md#apple-skill-references).
