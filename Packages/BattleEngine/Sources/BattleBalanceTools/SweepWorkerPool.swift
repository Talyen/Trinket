import Dispatch
import Foundation

enum SweepWorkerPool {
    static func forEach(
        count: Int,
        jobs: Int,
        work: @escaping @Sendable (Int) -> Void,
    ) {
        guard count > 0 else { return }
        let cpuCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let effectiveJobs = jobs <= 0 ? cpuCount : jobs
        let workers = max(1, min(effectiveJobs, count, cpuCount))
        guard workers > 1 else {
            for index in 0 ..< count {
                work(index)
            }
            return
        }
        let cursor = ClaimCursor()
        let group = DispatchGroup()
        for _ in 0 ..< workers {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                while let index = cursor.claim(count: count) {
                    work(index)
                }
                group.leave()
            }
        }
        group.wait()
    }
}

// Concurrency-Safety: all mutable state behind NSLock; claim hands each index to one worker.
private final class ClaimCursor: @unchecked Sendable {
    private let lock = NSLock()
    private var next = 0

    func claim(count: Int) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        guard next < count else { return nil }
        defer { next += 1 }
        return next
    }
}
