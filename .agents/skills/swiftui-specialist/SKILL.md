---
name: swiftui-specialist
description: Implement or review SwiftUI state, observation, environment, view identity, structure, animation, and localization using Apple's technical references. Use for correctness and performance work; player-facing design decisions also use apple-design.
---

# SwiftUI implementation

Load just the reference section relevant to your change, and apply Apple's
examples within the ownership and product contracts in
[SwiftUI feature context](../../../Docs/AgentContext/swiftui-features.md).

| Concern | Reference |
| --- | --- |
| View inputs | [Passing data](references/dataflow.md#passing-data-into-views) |
| `@State` and bindings | [Local state](references/dataflow.md#view-local-state-with-state), [Bindings](references/dataflow.md#bindings) |
| `@Observable` dependencies | [Property granularity](references/dataflow.md#per-property-dependency-granularity-on-observable-models), [Computed properties](references/dataflow.md#derived-values-and-caching) |
| `onChange` dependencies | [Side effects](references/dataflow.md#isolating-onchangeof-side-effect-invalidation) |
| Custom environment actions | [Closures](references/environment.md#closures-in-the-environment) |
| `@Entry` defaults | [Unstable defaults](references/environment.md#unstable-environment-default-values) |
| Frequent environment updates | [Rapid updates](references/environment.md#rapidly-updating-environment-values) |
| Collection identity | [Avoid index identity](references/foreach.md#avoid-collection-indices-as-identity), [Identity lifetime](references/foreach.md#identity-must-outlive-the-view-that-renders-the-foreach) |
| Collection update cost | [Cheap IDs](references/foreach.md#keep-the-id-cheap-to-hash), [Sorting and filtering](references/foreach.md#sorting-and-filtering) |
| `List` row structure | [Unary rows](references/foreach.md#prefer-unary-row-views-in-list) |
| Separate view update boundaries, cheap initializers, single-child `Group` | [View structure](references/structure.md) |
| Conditional modifiers and `AnyShapeStyle` | [Modifiers](references/modifiers.md) |
| Custom `Animatable` implementations and macros | [Animations](references/animations.md) |
| Localizable text, package bundles, interpolation, formatting | [Localization](references/localization.md) |
| Choosing a replacement for a soft-deprecated API | [Migration scope](references/soft-deprecation.md), then search the [API catalog](references/soft-deprecated-apis.md) for that symbol |

For SDK 27 migration errors or new APIs, see
[swiftui-whats-new-27](../swiftui-whats-new-27/SKILL.md). For layout, gestures,
motion design, materials, typography, or player-facing copy, see
[apple-design](../apple-design/SKILL.md).

Treat a matching pattern in a reference as a lead rather than an automatic
defect—trace the actual inputs, identity, and lifecycle, and preserve the app's
existing observation and resource owners instead of adding model layers just to
mirror an example. See
[Verification.md](../../../Docs/Platform/Verification.md#choosing-ui-verification)
for UI verification and
[Apple skill references](../../../Docs/Platform/ApplePlatformReference.md#apple-skill-references)
for snapshot version and refresh notes.
