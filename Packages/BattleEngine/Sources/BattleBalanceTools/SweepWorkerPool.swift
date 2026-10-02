import Dispatch
import Foundation
import Synchronization

enum SweepWorkerPool {
    /// Computes each index once, omits nil results, and returns in work order.
    /// Simulations run outside the lock; only claims and result storage serialize.
    static func map<T: Sendable>(
        count: Int,
        jobs: Int,
        work: @escaping @Sendable (Int) -> T?,
    ) -> [T] {
        guard count > 0 else { return [] }
        let cpuCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let effectiveJobs = jobs <= 0 ? cpuCount : jobs
        let workers = max(1, min(effectiveJobs, count, cpuCount))
        guard workers > 1 else {
            return (0 ..< count).compactMap(work)
        }

        let state = Mutex((next: 0, results: [T?](repeating: nil, count: count)))
        DispatchQueue.concurrentPerform(iterations: workers) { _ in
            while let index = state.withLock({ state -> Int? in
                guard state.next < count else { return nil }
                defer { state.next += 1 }
                return state.next
            }) {
                let result = work(index)
                state.withLock { $0.results[index] = result }
            }
        }
        return state.withLock { $0.results.compactMap(\.self) }
    }
}
