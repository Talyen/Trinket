# 04. Risk-Led Correctness Audit

**Goal:** Find and fix consequential wrong behavior through risk-led investigation.

Use the [shared audit contract](README.md) for scope, evidence, severity, and sizing.
Start from important player flows, rule boundaries, error/retry paths, or recent
fragile changes and develop hypotheses.

## Confirmation

Establish expected behavior from product rules, contracts, and the relevant owner,
then show how a reachable input or transition violates it. Existing tests can be
incomplete or wrong; compare their expectations with the intended behavior.
Trace across UI, engine, stores, content/configuration, and tests as needed to
identify the cause and all confirmed manifestations.

Useful candidates include invalid bounds/arithmetic, inconsistent rule application,
double-triggered actions, stuck state, configuration/content mismatches, and failures
that cannot return to a usable state. Syntax alone does not prove any of them.

## Remedy and boundaries

Preserve intended balance, copy, and product composition. Do not bundle unrelated
renaming, styling, refactoring, or speculative hardening with a correctness fix.

Use this audit for correctness findings without a more specific owner. Route
confirmed defects through the shared confusable-pairs table (durable
transaction/recovery failures, dead/parallel/ceremonial surface, and other
overlaps each have an owner there) without launching sibling inventories.
