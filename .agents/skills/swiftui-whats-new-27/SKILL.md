---
name: swiftui-whats-new-27
description: Diagnose SwiftUI SDK 27 migration errors and adopt its new APIs. Use for State macro or ContentBuilder changes, reorderable containers, AsyncImage caching, swipe actions, toolbar changes, and item-based alerts or dialogs.
---

# SwiftUI SDK 27 adoption

Read the relevant reference before changing a new or changed SDK 27 API.
Distinguish compiler changes, runtime behavior, and API availability: building
with SDK 27 does not make every new API available on older supported systems.
Use the reference's per-symbol availability and verify the selected SDK's public
declaration when a signature or version is uncertain.

| Symptom or capability | Reference |
| --- | --- |
| `@State` initialization, synthesized-property collisions, missing memberwise initializers after an SDK update | [State macro](references/state-macro.md) |
| `@ViewBuilder` / `@ContentBuilder` ambiguity, `TupleContent`, MapKit or Charts builder errors | [Content builders](references/content-builder.md) |
| Drag-to-reorder containers and applying `ReorderDifference` | [Reorderable containers](references/reorderable.md) |
| URL image caching, request policies, custom image sessions | [AsyncImage](references/async-image.md) |
| Swipe actions outside `List` and presentation callbacks | [Swipe actions](references/swipe-actions.md) |
| Toolbar overflow, pinning, visibility, and dynamic content | [Toolbar](references/toolbar.md) |
| Alerts and confirmation dialogs driven by an optional item | [Item binding](references/item-binding.md) |

For SDK-update errors involving `@State`, consult the State reference before
reordering initializer assignments: assigning to already-initialized state can
compile while retaining the wrong initial value. Preserve the initialization
semantics, not just compilation.

[Platform support](../../../Docs/Platform/ApplePlatformReference.md#platform-support)
owns the supported OS window and availability strategy. Evaluate useful new
APIs within that window; a compiler fix does not require raising the deployment
target. [SwiftUI feature context](../../../Docs/AgentContext/swiftui-features.md)
owns interaction and presentation contracts, including toolbar choices.
For artwork work, load [UI performance](../../../Docs/AgentContext/ui-performance.md):
the URL-image reference does not replace Trinket's prepared artwork pipeline.

Use [swiftui-specialist](../swiftui-specialist/SKILL.md) for non-version-specific
implementation questions and [apple-design](../apple-design/SKILL.md) for visual
or interaction changes. Verification follows
[Verification.md](../../../Docs/Platform/Verification.md).

Source version, local adaptations, and refresh procedure:
[Apple skill references](../../../Docs/Platform/ApplePlatformReference.md#apple-skill-references).
