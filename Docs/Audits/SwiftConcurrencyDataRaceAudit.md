# Swift Concurrency & Data Race Audit

**Goal:** Close Swift 6 concurrency gaps and data-race risks under `SWIFT_STRICT_CONCURRENCY=complete`.

## Intent

Start with strict-concurrency diagnostics when available, then investigate high-risk candidates. Do not add actors, async APIs, cancellation machinery, or concurrency tests without a compiler diagnostic or demonstrated lifetime/data-race issue. Write a plan to fix all identified concurrency/data-race issues (breaking into phases if the scope is large); significant isolation changes are proposals.

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

- **Unsynchronized Shared State:** Search for stored `static var` declarations across `Trinket/` and `Packages/`; verify protection via `@MainActor` or Swift 6 `Mutex`.
- **Undocumented Isolation Escapes:** Search for `@unchecked Sendable` or `nonisolated(unsafe)`; verify every occurrence includes `/// Concurrency-Safety:` documentation and adequate synchronization.
- **Main-Thread Hitches & Heavy Work Hops:** Search for heavy CPU work (image rasterization, json decoding, percentile analysis) running directly inside `@MainActor` methods without offloading to utility tasks.
- **Unstructured Task Capture Leaks:** Search for `Task { ... }` inside stored properties or views; verify `@MainActor` state is weakly captured (`[weak self]`, `[weak session]`) or cancelled in `deinit` / `.onDisappear`.
- **Cooperative Pool Thread Blocking:** Search for `Thread.sleep`, `usleep`, semaphores (`DispatchSemaphore`), or synchronous `Data(contentsOf:)` inside async contexts.
- **Legacy `DispatchQueue` Bridges:** Search for `DispatchQueue.main.async`, `DispatchQueue.global()`, or `@preconcurrency import` that can be modernized with Swift Concurrency.
