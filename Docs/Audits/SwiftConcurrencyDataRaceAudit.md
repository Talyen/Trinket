# Swift Concurrency & Data Race Audit

Goal: Ensure strict thread safety, prevent data races, and achieve full compatibility with Swift 6 Concurrency boundaries across all packages and the main app target.

Point-in-time audit snapshot. Use the agent prompt below to task a coding agent with one focused concurrency audit pass. Do not treat this as standing product requirements unless explicitly cited.

## Agent Prompt

Copy everything between the markers into a new agent session:

```text
--- BEGIN SWIFT CONCURRENCY AUDIT TASK ---

You are working on Trinket, a portrait-first iOS fantasy idle auto-battler (Swift 6 / SwiftUI, iOS 26). Read `AGENTS.md` and `Docs/Architecture.md` before editing.

**Mission:** Find and resolve Swift Concurrency gaps, thread safety issues, and data race risks by running five targeted search probes. Triage findings using the priority scoring rubric, implement thread-safe fixes, and verify that the test suites pass.

**Hard Stops:**
- Do not read every file — run the probes, triage, and select the highest-value issues.
- Do not touch generated files (e.g., `Generated/*`) directly — modify the codegen script or manifest and regenerate.
- Do not bypass Swift Concurrency checks using `@unchecked Sendable` or `nonisolated(unsafe)` unless you implement synchronized thread safety and document it with an explicit safety rationale comment.
- Do not introduce synchronous thread-blocking operations (e.g., `Thread.sleep`, raw semaphores) into cooperative concurrency contexts.

**Workflow:**
1. **Probe** — Run the five concurrency probes below. Group the matching lines by file.
2. **Triage** — Score findings using the Concurrency Severity Rubric (P0 to P4).
3. **Plan** — Focus on P0–P2 issues first. Write a brief fix plan outlining synchronization mechanisms (e.g., Actor isolation, Mutex, OSAllocatedUnfairLock).
4. **Fix** — Apply atomic thread-safety modifications. Document unchecked Sendable wrappers with a standard safety comment: `// Concurrency-Safety: <details>`.
5. **Verify** — Build and run `./Scripts/test.sh unit` to ensure compilation and tests succeed.
6. **Report** — Summarize findings, severity distribution, changes made, and recommended follow-up probes.

---

## Concurrency Probes

### Probe 1: Mutable Shared Static State
Find stored mutable static variables (ignores read-only computed properties):
```bash
rg -n 'static var\s+\w+\s*(:\s*[^\{]+)?\s*=' --type swift -g '!*Tests*' -g '!*UITests*' -g '!*Generated*' .
```
*Triage:* Verify if the variable is isolated to an actor, wrapped in a lock/Mutex, or if it can be replaced with a read-only `static let`.

### Probe 2: Compiler Safety Bypasses
Identify unchecked Sendable declarations and unsafe isolation escapes:
```bash
rg -n '@unchecked Sendable|nonisolated\(unsafe\)' --type swift -g '!*Tests*' -g '!*UITests*' .
```
*Triage:* Ensure each bypass is documented with an internal synchronization method. Key targets include [AbilityComparisonRowCollector](../../Packages/BattleEngine/Sources/BattleBalanceTools/AbilityComparisonAnalyzer.swift#L242) and [MatchupRowCollector](../../Packages/BattleEngine/Sources/BattleBalanceTools/BalanceSweepRunner.swift#L103).

### Probe 3: Legacy Dispatch Bridging
Locate Grand Central Dispatch (GCD) queues crossing actor/concurrency boundaries:
```bash
rg -n 'DispatchQueue\.(main|global|shared)' --type swift -g '!*Tests*' -g '!*UITests*' .
```
*Triage:* Prefer `@MainActor.run` or actor isolation over `DispatchQueue.main.async` (e.g., in [ChapterStageSelectView.swift](../../Trinket/Features/Play/PlayMap/ChapterStageSelectView.swift#L110)).

### Probe 4: Cooperative Thread Starvation (Blocking Calls)
Identify operations that block the cooperative pool (sleeps, semaphore waits, synchronous file loading):
```bash
rg -n '\bsleep\(|\busleep\(|\bThread\.sleep\(|\.wait\(|\bData\(contentsOf:' --type swift -g '!*Tests*' -g '!*UITests*' .
```
*Triage:* Replace thread-blocking operations in async methods with non-blocking equivalents (e.g., `Task.sleep` or asynchronous I/O).

### Probe 5: Project Concurrency Configuration
Verify that complete concurrency checking is enforced. Check [project.yml](../../project.yml) and package files:
```bash
rg -n 'SWIFT_TREAT_WARNINGS_AS_ERRORS|SWIFT_CONCURRENCY_CHECKS|OTHER_SWIFT_FLAGS' --type yaml --type swift .
```
*Triage:* Ensure targets specify strict warning-as-error compilation settings.

---

## Concurrency Severity Rubric

| Severity | Type | Description | Target |
| :--- | :--- | :--- | :--- |
| **P0** | Active Data Race / Crash | Shared mutable state modified concurrently without synchronization (e.g., in simulation loop or save logic). | Must fix immediately. |
| **P1** | Undocumented Compiler Escape | Usage of `@unchecked Sendable` or `nonisolated(unsafe)` without a documented synchronization explanation. | Must document or refactor. |
| **P2** | Thread Starvation Hazard | Sync blocking call (`Thread.sleep`, `Data(contentsOf:)`) running inside an actor or main-thread rendering loop. | Offload or convert to async. |
| **P3** | Legacy Thread Bridging | `DispatchQueue` used instead of modern actor-isolation / Task structures. | Refactor to Swift Concurrency. |
| **P4** | Detached Task context leak | `Task.detached` used where context inheritance (Task local, actor isolation) is preferred. | Convert to structured Task. |

---

## Remediations & Safe Patterns

### Actor Isolation for UI States
Ensure classes updating UI conform to `@MainActor`:
```swift
@MainActor
@Observable
public final class BattleSession {
    // Automatically runs UI updates on MainActor
}
```

### Thread-Safe Internal Locks
For utility classes that cannot use async actors, implement synchronization using `Mutex` (Swift 6+) or `OSAllocatedUnfairLock`:
```swift
// Swift 6 Mutex Pattern
import Synchronization

public final class MatchupRowCollector: Sendable {
    private let storage: Mutex<[MatchupSweepRow?]>
    
    public init(capacity: Int) {
        self.storage = Mutex(Array(repeating: nil, count: capacity))
    }
    
    public func store(_ row: MatchupSweepRow, at index: Int) {
        storage.withLock { array in
            array[index] = row
        }
    }
}
```

### Safe Task Closures
Avoid retaining `self` implicitly in View task closures:
```swift
.task { [weak self] in
    guard let self else { return }
    await self.loadData()
}
```

---

## Verification Plan

### Automated Checks
*   **Compile:** Run `build.sh` to ensure there are no build errors.
*   **Warnings:** Verify compilation log has zero warnings related to Sendable, concurrency, or isolation boundaries.
*   **Tests:** Run `./Scripts/test.sh unit` to verify package and app logic remain deterministic.
```
