---
name: architect
description: Choose ownership and the smallest usable contract when adding or changing public Swift types, protocols, or schemas under Packages/*/Sources/. Use for package boundary decisions, not routine private helpers.
---

# Choose the owner before the API

Use the [architecture map](../../../Docs/Platform/Architecture.md) for package
dependency rules and hub containment, and the owning package guide for its
extension points.

When adding or changing a public surface:

- Check whether an existing type or operation already covers the behavior.
- Keep visibility as narrow as the consumer needs—a new type doesn't need to be
  `public` by default, and a single implementation rarely needs a protocol.
- Look at the call site as well as the declaration so the consumer gets what it
  needs without forwarding wrappers or access to unrelated state.
- For serialized schemas, check all readers and writers and follow the root
  guide's preservation and migration rules.
- If considering a package split, check
  [deferred seams](../../../Docs/Platform/Architecture.md#deferred-architecture-seams)
  first.
