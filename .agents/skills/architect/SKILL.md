---
name: architect
description: Auto-triggers when adding public Swift types, protocols, or schemas under Packages/*/Sources/. Nudges draft-public-API-first before implementation.
---

# Draft the public surface first

When adding a package type, protocol, or schema, write the public declarations
and their domain invariants before implementation bodies. Keep the surface
minimal; boundary rules are enforced by `check-module-boundaries.sh` at
verification.
