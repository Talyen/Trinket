# 06. Dead, Parallel & Ceremonial Surface Audit

**Goal:** Remove authored surface that has no consumer or adds no distinct behavior,
meaningful clarity, or enforced boundary.

Use the [shared audit contract](README.md) for scope, evidence, severity, and sizing.

## Classification and evidence

| Class | Confirmation |
|-------|--------------|
| Dead | No live consumer after considering product, tests, package clients, manifests, resources, configuration, generated references, and dynamic/registration hooks |
| Parallel | Reachable paths duplicate the same responsibility without a distinct contract, and one owner can preserve the consumers' required behavior |
| Ceremonial | A simpler form in the current owner removes demonstrated reading/editing cost while preserving behavior and meaningful boundaries |

One conformer, one caller, a forwarding method, a typealias, or a manager name is
not proof. A small seam can enforce isolation, lifecycle, dependency direction,
readability, or a supported client contract. Check the actual role before deleting it.

## Remedy

Delete dead roots and their now-unneeded dependents; retarget redundant callers to
the surviving owner; inline needless indirection where it improves clarity. Include
owned tests, flags, resources, configuration, and documentation tied to the removed
path. For generated surface, edit authored inputs and regenerate—never hand-edit output.
Demote unnecessary public API only after confirming the current package-client inventory.

A successful fix removes a real maintenance burden. Moving or wrapping the same
unnecessary surface is not removal; keeping a useful single-use boundary is valid.

## Boundaries

- Preserve app/package entry points, model/macro/registration hooks, dynamic resource
  lookups, and test-support consumers. Static analysis is candidate evidence, not
  proof of liveness or absence.
- Preserve live save/schema compatibility until its consumer window is proven closed;
  elapsed time alone is insufficient. Preserve intentional seams under
  [Architecture](../Platform/Architecture.md) and relevant [proposal memory](Proposals.md).
- Do not rewrite battle math, save wire formats, or meaningful tests for brevity.
- Misplaced responsibilities belong to [13](13_StateGravityOwnershipAudit.md);
  mixed-job maintenance cost belongs to [02](02_MaintenanceSurfaceLocalityAudit.md).
