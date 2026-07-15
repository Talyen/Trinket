# Swift Concurrency & Data Race Audit

**Goal:** Close Swift 6 concurrency gaps and data-race risks under `SWIFT_STRICT_CONCURRENCY=complete`.

## Intent

Start with a strict-concurrency build when available, then investigate diagnostics and high-risk candidates. Fix a bounded set of confirmed issues; a clean pass is valid. If several hits share one isolation or ownership model, prefer that root-cause remedy over N local annotations — and propose when significant per [README.md](README.md).

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

## Verify

`build.sh` is the primary Sendable/isolation check (toolchain permitting); `lint.sh` + boundaries; focused unit / `TrinketPersistence` package tests when stores are touched.
