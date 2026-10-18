import Foundation
import Testing
@testable import TrinketCore

@MainActor
struct MainActorCleanupTests {
    @Test func `main actor teardown releases its resource synchronously once`() {
        let counter = CleanupCounter()
        var cleanup: MainActorCleanup? = MainActorCleanup { counter.calls += 1 }
        weak let released = cleanup
        #expect(counter.calls == 0)
        cleanup = nil
        #expect(released == nil)
        #expect(counter.calls == 1)
    }

    @Test func `background teardown performs cleanup on the main actor once`() async {
        let counter = CleanupCounter()
        await Task.detached {
            Self.dropFromBackground(counter)
        }.value
        // Yield the main actor until the deinit-enqueued hop runs.
        // Bounded spin, no wall-clock sleeps.
        for _ in 0 ..< 1000 where counter.calls == 0 {
            await Task.yield()
        }
        #expect(counter.calls == 1)
    }

    private nonisolated static func dropFromBackground(_ counter: CleanupCounter) {
        #expect(!Thread.isMainThread)
        let cleanup = MainActorCleanup {
            MainActor.preconditionIsolated()
            counter.calls += 1
        }
        withExtendedLifetime(cleanup) {}
    }
}

@MainActor
private final class CleanupCounter {
    var calls = 0
}
