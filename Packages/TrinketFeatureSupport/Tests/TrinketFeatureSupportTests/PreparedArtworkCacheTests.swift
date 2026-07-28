import Testing
@testable import TrinketFeatureSupport

@MainActor
struct PreparedArtworkCacheTests {
    @Test func warmupPlanPutsPriorityNamesFirstAndPreservesCatalogOrder() {
        let plan = LaunchArtworkWarmupPlan.make(
            priorityImageNames: ["hero", "enemy", "missing"],
            catalogNames: ["a", "enemy", "b", "hero", "c"]
        )

        #expect(plan.priorityNames == ["enemy", "hero"])
        #expect(plan.deferredNames == ["a", "b", "c"])
    }

    @Test func prepareAllMarksLaunchCompleteAfterPriorityBeforeDeferredFinishes() async throws {
        let deferredGate = DeferredDecodeGate()
        let cache = PreparedArtworkCache.makeForTesting(
            catalogNames: ["priority-a", "priority-b", "deferred-a", "deferred-b"]
        ) { name in
            if name.hasPrefix("deferred-") {
                await deferredGate.waitUntilOpen()
            }
            return PreparedArtwork(name: name, image: nil)
        }

        let prepareTask = Task {
            await cache.prepareAll(priorityImageNames: ["priority-a", "priority-b"])
        }

        var unblocked = false
        for _ in 0 ..< 400 {
            if cache.isLaunchWarmupComplete {
                unblocked = true
                break
            }
            try await Task.sleep(for: .milliseconds(5))
        }

        #expect(unblocked)
        #expect(cache.isLaunchWarmupComplete)
        #expect(!cache.isDeferredWarmupComplete)
        #expect(cache.completedCount == 2)

        await deferredGate.open()
        // prepareAll returns once priority is done; wait for background deferred work.
        await prepareTask.value
        for _ in 0 ..< 400 where !cache.isDeferredWarmupComplete {
            try await Task.sleep(for: .milliseconds(5))
        }

        #expect(cache.isDeferredWarmupComplete)
        #expect(cache.completedCount == 4)
    }
}

private actor DeferredDecodeGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilOpen() async {
        if isOpen {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }
}
