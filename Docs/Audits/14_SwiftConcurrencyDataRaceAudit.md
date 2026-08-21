# 14. Swift Concurrency & Data Race Audit

**Goal:** Close Swift 6 concurrency gaps and data-race risks under `SWIFT_STRICT_CONCURRENCY=complete`.

## Intent

Fix confirmed concurrency violations and source-proven lifetime/isolation hazards. Do not add actors, async APIs, cancellation machinery, or concurrency tests without a compiler diagnostic, runtime reproduction, or a concrete source proof under the evidence bar below. Bounded isolation/cancellation corrections may follow the affected call chain.

## Hard stops

- Do not add `@unchecked Sendable` / `nonisolated(unsafe)` without a `// Concurrency-Safety:` rationale and real synchronization.
- Do not introduce `Thread.sleep`, semaphores, or other thread-blocking calls in cooperative contexts.
- Prefer structured `Task` over `Task.detached` unless isolation escape is required and documented.
- Do not relocate battle simulation off `@MainActor` unless Architecture already requires it.

## Severity

Because `SWIFT_STRICT_CONCURRENCY=complete` already fails the build on most isolation errors, this audit's value concentrates in P1–P2 — what the compiler accepts but should not be trusted.

| Sev | Description | Action |
|-----|-------------|--------|
| P0 | Unsynchronized shared mutable state on hot paths | Fix now |
| P1 | Undocumented `@unchecked` / `nonisolated(unsafe)` | Document or refactor |
| P2 | Blocking call on actor/main; leaking unstructured Task | Establish correct executor, ownership, and cancellation; do not convert APIs to async by default |
| P3 | `DispatchQueue` legacy bridge; unnecessary `Task.detached` | Modernize / prefer structured Task when touching |

## Domain rules

**Safe patterns:** `@MainActor` + `@Observable` for UI-facing state; `Mutex` (Synchronization) for shared mutable storage; SwiftUI `.task` cancels when the view goes away. Do **not** reflexively add `[weak self]` on `@MainActor` / `@Observable` types unless a retain cycle is proven — prefer cancellation checks and structured children.

Expect `SWIFT_STRICT_CONCURRENCY: complete` in `project.yml` / packages. Compiler cleanliness is necessary but not sufficient for lifetime behavior the type system cannot prove. Presence of continuations / `AsyncStream` / `TaskGroup` is not itself a defect — confirm lifetime, cancellation, executor, and termination assumptions.

## Evidence bar

One of:

- Compiler diagnostic under strict concurrency
- Runtime reproduction or test showing a race, leak, deadlock, invalid ordering, or cancellation/lifetime failure
- Concrete source proof: unsynchronized shared mutation; unstructured work escaping its owner without cancellation; blocking work on an actor/main executor; continuation that can resume zero or multiple times; stream without owned termination; isolation-erasing capture; or detached work whose executor/lifetime contradicts the caller contract

Fix the confirmed dependency/cancellation cone, not only the first diagnostic. Do not infer a hazard from syntax alone.
