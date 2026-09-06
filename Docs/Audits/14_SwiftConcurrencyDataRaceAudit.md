# 14. Swift Concurrency & Data Race Audit

**Goal:** Repair isolation, ordering, reentrancy, and task-lifetime failures that
strict concurrency checks alone may not establish.

Use the [shared audit contract](README.md) for scope, evidence, severity, and sizing.
[Verification](../Platform/Verification.md) owns concurrency gates;
[Architecture](../Platform/Architecture.md) owns actor and package boundaries.

## What to investigate

Unsynchronized shared mutation, actor state assumptions invalidated across `await`,
stale results applied after a newer request, blocking cooperative execution,
continuations resumed incorrectly, and work/streams whose lifetime violates the
consumer's contract. Compiler diagnostics, reproductions, and concrete source proofs
are valid evidence; syntax alone is not.

## Domain distinctions

[Swift concurrency documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Unstructured-Concurrency)
explains task structure and cancellation.

- `Task {}` and `Task.detached` create unstructured tasks. Inherited actor isolation
  does not make `Task {}` a structured child or automatically couple cancellation
  to its creator. Structured children use constructs such as `async let` or task groups.
- Unstructured work can be legitimate when its ownership/completion contract is
  clear. A missing cancellation hook is a finding only when the work must terminate
  or must not apply results after its owner/request becomes obsolete.
- Cancellation is cooperative. SwiftUI `.task` provides view-related cancellation,
  but work must still honor cancellation where the behavior requires it.
- Actor isolation prevents certain races, not logical interleaving across suspension.
  Confirm stale state/result handling without adding actors or async APIs reflexively.
- An unsafe isolation/Sendable escape needs the permitted rationale and actual
  synchronization under repository gates. Documentation alone does not make it safe.
- Retain cycles require evidence; do not add weak captures indiscriminately. A task
  finishing normally and a task retaining its owner indefinitely are different cases.

## Remedy and success

Repair the affected isolation/lifetime chain and verify the specific interleaving,
termination, or synchronization guarantee. Do not replace working bridges or add
cancellation machinery simply to modernize syntax. Preserve battle's main-actor
ownership unless Architecture changes; do not introduce blocking sleeps or semaphore
waits in cooperative contexts.

Transaction integrity belongs to [03](03_BehaviorHardeningAudit.md); non-concurrent
effect placement and initiation belong to [12](12_SideEffectSurfaceAudit.md).
