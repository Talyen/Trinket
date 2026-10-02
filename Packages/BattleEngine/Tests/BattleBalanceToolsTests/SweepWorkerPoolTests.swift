import Synchronization
import Testing
@testable import BattleBalanceTools

struct SweepWorkerPoolTests {
    @Test(arguments: [0, 1, 2, 3, 7, 64])
    func `every index runs exactly once and sparse results keep work order`(jobs: Int) {
        let visits = Mutex<[Int]>([])
        let results = SweepWorkerPool.map(count: 1024, jobs: jobs) { index in
            visits.withLock { $0.append(index) }
            return index.isMultiple(of: 3) ? nil : index
        }
        #expect(visits.withLock { $0.sorted() } == Array(0 ..< 1024))
        #expect(results == (0 ..< 1024).filter { !$0.isMultiple(of: 3) })
    }

    @Test func `empty work performs no visits`() {
        let visits = Mutex(0)
        let results = SweepWorkerPool.map(count: 0, jobs: 4) { index in
            visits.withLock { $0 += 1 }
            return index
        }
        #expect(visits.withLock { $0 } == 0)
        #expect(results.isEmpty)
    }
}
