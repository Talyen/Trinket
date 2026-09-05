---
name: architect
description: Choose ownership and the smallest usable contract when adding or changing public Swift types, protocols, or schemas under Packages/*/Sources/. Use for package boundary decisions, not routine private helpers.
---

# Choose the owner before the API

Identify the current consumer and owning package before adding a public surface.
Use the [architecture map](../../../Docs/Platform/Architecture.md) for dependency
rules and hub containment, then the owning package guide for its extension points.

- Check whether an existing type or operation already expresses the behavior.
- Choose the narrowest visibility the consumer needs. A new type does not by
  itself need to be public; a single implementation does not by itself need a protocol.
- Sketch the declarations and invariants before filling in substantial bodies.
  This can happen directly in the implementation; no separate proposal or stub
  phase is required for an ordinary change within an existing boundary.
- Review the call site as well as the declaration: does the consumer get the
  operation it needs without forwarding wrappers or access to unrelated state?
- For serialized schemas, identify readers and writers before changing the contract;
  follow the root guide's preservation and migration rules.

If considering a package split, consult the
[deferred seams](../../knowledge/patterns/architecture-deferred-seams.md).
Boundary checks verify dependency direction; review still needs to establish
whether the chosen owner and API make sense.
