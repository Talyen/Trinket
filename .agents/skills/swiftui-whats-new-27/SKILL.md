---
name: swiftui-whats-new-27
description: Diagnose SwiftUI SDK 27 migration errors and adopt its new APIs. Use for State macro or ContentBuilder changes, reorderable containers, AsyncImage caching, swipe actions, toolbar changes, and item-based alerts or dialogs.
---

# SwiftUI SDK 27 adoption

Use the relevant reference when diagnosing an SDK 27 migration error or adopting
a new API. Keep compiler changes, runtime behavior, and OS availability
distinct—building with SDK 27 doesn't make new APIs available on older supported
OS versions, so check per-symbol availability (and the SDK's public declaration
if anything looks uncertain).

| Symptom or capability | Reference |
| --- | --- |
| `@State` initialization, synthesized-property collisions, missing memberwise initializers after an SDK update | [State macro](references/state-macro.md) |
| `@ViewBuilder` / `@ContentBuilder` ambiguity, `TupleContent`, MapKit or Charts builder errors | [Content builders](references/content-builder.md) |
| Drag-to-reorder containers and applying `ReorderDifference` | [Reorderable containers](references/reorderable.md) |
| URL image caching, request policies, custom image sessions | [AsyncImage](references/async-image.md) |
| Swipe actions outside `List` and presentation callbacks | [Swipe actions](references/swipe-actions.md) |
| Toolbar overflow, pinning, visibility, and dynamic content | [Toolbar](references/toolbar.md) |
| Alerts and confirmation dialogs driven by an optional item | [Item binding](references/item-binding.md) |

Key gotchas:

- **`@State` initializers**: check [State macro](references/state-macro.md)
  before reordering assignments—assigning to already-initialized state can
  compile while silently keeping the wrong initial value.
- **Availability**: [Platform support](../../../Docs/Platform/ApplePlatformReference.md#platform-support)
  owns the supported OS window; a compiler fix doesn't require raising the
  deployment target.
- **Product contracts**: [SwiftUI feature context](../../../Docs/AgentContext/swiftui-features.md)
  covers interaction and toolbar conventions, and
  [UI performance](../../../Docs/AgentContext/ui-performance.md) owns Trinket's
  prepared artwork pipeline (separate from `AsyncImage`).

See [swiftui-specialist](../swiftui-specialist/SKILL.md) for general SwiftUI
implementation, [apple-design](../apple-design/SKILL.md) for visual or
interaction design, [Verification.md](../../../Docs/Platform/Verification.md)
for verification, and
[Apple skill references](../../../Docs/Platform/ApplePlatformReference.md#apple-skill-references)
for snapshot version and refresh notes.
