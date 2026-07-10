# Swift Concurrency & Data Race Audit

Goal: Close Swift 6 concurrency gaps and data-race risks under `SWIFT_STRICT_CONCURRENCY=complete`.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Start with a strict-concurrency build when available, then use probes to investigate its diagnostics and high-risk candidates. Fix a bounded set of confirmed issues; a clean pass is valid.

## Hard stops

- Do not hand-edit `Generated/*`.
- Do not add `@unchecked Sendable` / `nonisolated(unsafe)` without a `// Concurrency-Safety:` rationale and real synchronization.
- Do not introduce `Thread.sleep`, semaphores, or other thread-blocking calls in cooperative contexts.
- Prefer structured `Task` over `Task.detached` unless isolation escape is required and documented.
- Do not relocate battle simulation off `@MainActor` unless Architecture already requires it.

## Probes

### 1. Mutable shared static state

```bash
rg -n 'static var\s+\w+\s*(:\s*[^\{]+)?\s*=' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'
```

Triage: actor-isolated (including `@MainActor` where appropriate), locked/`Mutex`, immutable, or otherwise proven safe.

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

Establish the current executor and call frequency before changing blocking I/O; use async or off-actor work only when the hot path requires it.

### 5. Unstructured tasks & isolation hotspots

```bash
rg -n 'Task\.detached|Task\s*\{' --type swift \
  Trinket/State Trinket/BattleShell Packages/TrinketPersistence/Sources \
  -g '!*Tests*' -g '!**/Generated/*' | head -80

rg -n '@MainActor|@Observable' --type swift \
  Trinket/State/AppState.swift Trinket/State/BattleSession.swift \
  Packages/TrinketPersistence/Sources -g '!*Tests*' | head -40
```

Check: unstructured `Task { }` on `@Observable` / store types cancel on teardown; prefer structured children; document any required `Task.detached`.

### 6. Other isolation escapes

```bash
rg -n '@preconcurrency|MainActor\.assumeIsolated|withUnsafeContinuation|withCheckedContinuation|AsyncStream|TaskGroup' \
  --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'
```

Confirm the lifetime, cancellation, and executor assumptions for every candidate; the presence of one is not itself a defect.

### 7. Project concurrency configuration

```bash
rg -n 'SWIFT_STRICT_CONCURRENCY|SWIFT_TREAT_WARNINGS_AS_ERRORS' project.yml Packages/*/Package.swift
```

Expect `SWIFT_STRICT_CONCURRENCY: complete` (or equivalent package setting). Do not invent alternate flag names.

## Severity

| Sev | Description | Action |
|-----|-------------|--------|
| P0 | Unsynchronized shared mutable state on hot paths | Fix now |
| P1 | Undocumented `@unchecked` / `nonisolated(unsafe)` | Document or refactor |
| P2 | Blocking call on actor/main; leaking unstructured Task | Establish the correct executor, ownership, and cancellation; do not convert APIs to async by default |
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
./Scripts/build.sh   # toolchain permitting — primary check for Sendable/isolation errors
./Scripts/check-module-boundaries.sh
./Scripts/lint.sh
# Narrow when the diff is focused:
./Scripts/test.sh unit <FocusedClass>
./Scripts/test-package.sh TrinketPersistence   # if stores touched
# Broad only when cross-cutting:
./Scripts/test.sh unit
```

If Xcode is unavailable, still fix clear probe hits and state in the commit body that build/unit verification was skipped (see [README.md](README.md) § Cloud / no-Xcode toolchain).

## Commit

```
fix(<scope>): close <concurrency hazard>

- <probe + fix>
- Concurrency-Safety documented where bypass remains

User-Facing: no
```
