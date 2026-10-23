# 13. State Gravity & Ownership Audit

**Goal:** Restore coherent responsibility and state authority when logic or mutable
state has accumulated in the wrong owner.

Apply the [shared audit contract](README.md).
[Architecture](../Platform/Architecture.md) owns module responsibilities, hub
containment, and intentional orchestration seams.

## What to investigate

Rules enforced independently by callers, competing mutable/derived state, persistence
policy in presentation, presentation lifetime on save types, and feature-specific
logic accumulating on broad facades. Large types, catalog reads in views, session
names, and forwarding methods are only leads: composition and adapters have real jobs.

## Evidence and remedy

Identify a concrete architecture violation or competing authority for the same
invariant, and explain its correctness or maintenance cost. Name the intended owner
and the state/lifetime contract it should enforce. Prefer an existing engine handler,
store slice, feature session, or presentation owner; a new boundary needs a proposal.

Move the complete responsibility and affected callers/tests, removing obsolete
mirrors and indirection. Preserve intentional forwarders and independently justified
snapshots; not all repeated values are competing mutable state. A fix may be
LOC-neutral or grow when it establishes the right invariant or lifetime boundary.
Verify that mutations and reads now follow one intended authority and that no
replaced behavior remains active.

## Boundaries

- Preserve Architecture's package DAG and SwiftUI-free domain/contracts boundaries.
- Preserve the live `BattleSession`'s main-actor ownership and accepted seams.
  Pure BattleEngine commands and headless tools follow the
  [engine's calling-thread contract](../AgentContext/battle-engine.md); they are
  not main-actor APIs. Changing those ownership boundaries requires the relevant
  architectural decision and evidence.
- Repair straightforward import-gate failures directly rather than inflating them
  into a hub rewrite.
