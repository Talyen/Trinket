# 06. Dead, Parallel & Ceremonial Surface Audit

**Goal:** Remove authored surface that has no consumer, duplicates a live path, or
adds ceremony without a distinct behavior or enforced boundary.

## Intent

Classify the candidate by liveness, then delete the complete unnecessary cone:
source, callers, flags, resources, configuration, generated inputs/output, tests,
documentation, and exported API. A successful fix leaves less authored surface;
moving or wrapping the same surface is not success.

## Classification

| Class | Confirmation |
|-------|--------------|
| Dead | No live consumer across product, tests, manifests, generated output, registration/dynamic hooks, resources, configuration, docs-defined entry points, or package clients |
| Parallel | Two reachable paths produce one behavior, or a reachable shim only forwards to the surviving owner |
| Ceremonial | One live path has no second need and a shorter form in the same owner preserves behavior |

Wrong-owner hits belong to [13](13_StateGravityOwnershipAudit.md), even when a
leftover twin is also present. Large single-path surfaces whose primary cost is
mixed jobs belong to [02](02_MaintenanceSurfaceLocalityAudit.md).

## Example signals

- Unused types, views, enum cases, resources, dependencies, flags, fixtures, or
  generated inputs
- Forwarding wrappers, rename-only typealiases, deprecated entries, permanent
  feature switches, or parallel implementations with no distinct consumer
- Protocol plus one conformer/factory, single-use managers/helpers/config objects,
  boolean parameter soup, defensive fallback stacks without a real failure mode,
  or repeated near-duplicate blocks
- Unnecessary `public` API used only inside its package

## Hard stops

- Prove a candidate is not an app/package entry point, protocol or macro
  registration, SwiftData/model hook, dynamic lookup, or external package API.
- Do not delete manifest-backed or generated surface without editing the authored
  input and regenerating.
- Do not collapse intentional seams recorded in [Proposals.md](Proposals.md) or
  prescribed by Architecture.
- Do not remove save/schema compatibility until the consumer window is proven
  closed; elapsed time alone is not evidence.
- Do not rewrite battle pipeline math, save wire format, or meaningful tests merely
  for brevity.
- Test-support fixtures are not dead because product code does not call them.

## Evidence bar

Meet one classification row above and identify a deletion/inlining remedy that
preserves behavior. Parallel migration additionally requires proof that the old
consumer window is closed. Ceremony requires real reading/editing cost, no second
need, and a shorter form within the current owner.

## Domain rules

Prefer delete dead roots → retarget reachable callers to the surviving path →
remove the compatibility envelope → inline single-use ceremony → parameterize a
confirmed repeated block only when that is smaller and clearer. Demote package API
to `internal` when it remains useful only within the package. Do not leave a
pass-through compatibility name after callers move.

Use `check-unused-assets.py` for manifest/resource integrity and the repository's
dead-code/static-analysis tooling as candidate evidence, not automatic proof. The
compiler and package-client inventory remain authoritative for live Swift API.
