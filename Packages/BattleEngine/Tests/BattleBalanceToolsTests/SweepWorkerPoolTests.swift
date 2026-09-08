import Foundation
import Testing
@testable import BattleBalanceTools

struct SweepWorkerPoolTests {
    @Test(arguments: [0, 1, 2, 3, 7, 64])
    func `every index runs exactly once`(jobs: Int) {
        let log = VisitLog()
        SweepWorkerPool.forEach(count: 64, jobs: jobs) { index in
            log.append(index)
        }
        #expect(log.sorted == Array(0 ..< 64))
    }

    @Test func `empty work performs no visits`() {
        let log = VisitLog()
        SweepWorkerPool.forEach(count: 0, jobs: 4) { index in
            log.append(index)
        }
        #expect(log.sorted.isEmpty)
    }
}

// Concurrency-Safety: test-only log with all mutations behind NSLock.
private final class VisitLog: @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [Int] = []

    func append(_ index: Int) {
        lock.lock()
        defer { lock.unlock() }
        seen.append(index)
    }

    var sorted: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return seen.sorted()
    }
}
