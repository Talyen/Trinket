# Swift Concurrency & Data Race Audit

**Goal:** Close Swift 6 concurrency gaps and data-race risks under `SWIFT_STRICT_CONCURRENCY=complete`.

## Intent

Start with strict-concurrency diagnostics when available, then investigate high-risk candidates. Do not add actors, async APIs, cancellation machinery, or concurrency tests without a compiler diagnostic or demonstrated lifetime/data-race issue. Fix one bounded cluster; significant isolation changes are proposals.

## Hard stops

- Do not add `@unchecked Sendable` / `nonisolated(unsafe)` without a `// Concurrency-Safety:` rationale and real synchronization.
- Do not introduce `Thread.sleep`, semaphores, or other thread-blocking calls in cooperative contexts.
- Prefer structured `Task` over `Task.detached` unless isolation escape is required and documented.
- Do not relocate battle simulation off `@MainActor` unless Architecture already requires it.

## Severity

| Sev | Description | Action |
|-----|-------------|--------|
| P0 | Unsynchronized shared mutable state on hot paths | Fix now |
| P1 | Undocumented `@unchecked` / `nonisolated(unsafe)` | Document or refactor |
| P2 | Blocking call on actor/main; leaking unstructured Task | Establish correct executor, ownership, and cancellation; do not convert APIs to async by default |
| P3 | `DispatchQueue` legacy bridge | Modernize when touching |
| P4 | Unnecessary `Task.detached` | Prefer structured Task |

## Domain rules

**Safe patterns:** `@MainActor` + `@Observable` for UI-facing state; `Mutex` (Synchronization) for shared mutable storage; SwiftUI `.task` cancels when the view goes away. Do **not** reflexively add `[weak self]` on `@MainActor` / `@Observable` types unless a retain cycle is proven — prefer cancellation checks and structured children.

Expect `SWIFT_STRICT_CONCURRENCY: complete` in `project.yml` / packages. Presence of continuations / `AsyncStream` / `TaskGroup` is not itself a defect — confirm lifetime, cancellation, and executor assumptions.

## Probe hints

Mutable `static var`; `@unchecked Sendable` / `nonisolated(unsafe)`; `DispatchQueue.main`/`global`; cooperative-pool blocking (`sleep`, `Thread.sleep`, sync `Data(contentsOf:)`); unstructured `Task` / `Task.detached` on stores and shell; isolation escapes (`@preconcurrency`, `assumeIsolated`, continuations).
