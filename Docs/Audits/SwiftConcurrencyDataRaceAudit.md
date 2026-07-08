# Swift Concurrency & Data Race Audit

Goal: Close Swift 6 concurrency gaps and data-race risks under `SWIFT_STRICT_CONCURRENCY=complete`.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Run five probes, triage P0–P2 first, fix up to **5** issues, verify with unit tests, commit.

## Hard stops

- Do not hand-edit `Generated/*`.
- Do not add `@unchecked Sendable` / `nonisolated(unsafe)` without a `// Concurrency-Safety:` rationale and real synchronization.
- Do not introduce `Thread.sleep`, semaphores, or other thread-blocking calls in cooperative contexts.
- Prefer structured `Task` over `Task.detached` unless isolation escape is required and documented.

## Probes

### 1. Mutable shared static state

```bash
rg -n 'static var\s+\w+\s*(:\s*[^\{]+)?\s*=' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'
```

Triage: actor-isolated, locked/`Mutex`, or convert to `static let`.

### 2. Compiler safety bypasses

```bash
rg -n '@unchecked Sendable|nonisolated\(unsafe\)' --type swift -g '!*Tests*' -g '!*UITests*'
```

Each bypass needs documented synchronization. Prefer removing the bypass when types allow.

### 3. Legacy Dispatch bridging

```bash
rg -n 'DispatchQueue\.(main|global)' --type swift -g '!*Tests*' -g '!*UITests*'
```

Prefer `@MainActor` / `MainActor.run` / actor isolation over `DispatchQueue.main.async`.

### 4. Cooperative pool blocking

```bash
rg -n '\bsleep\(|\busleep\(|\bThread\.sleep\(|\bData\(contentsOf:' --type swift -g '!*Tests*' -g '!*UITests*'
```

Replace with `Task.sleep` / async I/O off the cooperative hot path.

### 5. Project concurrency configuration

```bash
rg -n 'SWIFT_STRICT_CONCURRENCY|SWIFT_TREAT_WARNINGS_AS_ERRORS' project.yml Packages/*/Package.swift
```

Expect `SWIFT_STRICT_CONCURRENCY: complete` (or equivalent package setting). Do not invent alternate flag names.

## Severity

| Sev | Description | Action |
|-----|-------------|--------|
| P0 | Unsynchronized shared mutable state on hot paths | Fix now |
| P1 | Undocumented `@unchecked` / `nonisolated(unsafe)` | Document or refactor |
| P2 | Blocking call on actor/main | Offload / async |
| P3 | `DispatchQueue` legacy bridge | Modernize when touching |
| P4 | Unnecessary `Task.detached` | Prefer structured Task |

## Safe patterns

```swift
@MainActor
@Observable
final class BattleSession { /* UI-facing state */ }
```

```swift
import Synchronization

public final class RowCollector: Sendable {
    private let storage: Mutex<[Row?]>
    // ...
}
```

SwiftUI `.task` is cancelled when the view goes away. Do **not** reflexively add `[weak self]` on `@MainActor` / `@Observable` view models unless a retain cycle is proven — prefer cancellation checks and structured children.

## Verification

```sh
./Scripts/build.sh
./Scripts/test.sh unit
./Scripts/check-module-boundaries.sh
./Scripts/lint.sh
```

Confirm the build log has no new Sendable/isolation errors.

## Commit

```
fix(<scope>): close <concurrency hazard>

- <probe + fix>
- Concurrency-Safety documented where bypass remains

User-Facing: no
```
