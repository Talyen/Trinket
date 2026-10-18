import Foundation
import Testing
@testable import TrinketFeatureSupport

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct ArtworkDecodeSchedulerTests {
    @Test func `decoded artwork publishes on the main actor`() async {
        // Publish runs under MainActor.run after the fix, so these appends
        // are main-actor bound without hops or locks.
        var published: [(name: String, mainThread: Bool)] = []
        let scheduler = ArtworkDecodeScheduler(
            decode: { PreparedArtwork(name: $0, image: nil) },
            publish: { prepared in
                published.append((prepared.name, Thread.isMainThread))
            },
        )
        var finishedCount = 0
        await scheduler.prepare(["a", "b"], priority: .imminent) {
            finishedCount += 1
        }

        #expect(Set(published.map(\.name)) == ["a", "b"])
        #expect(published.count == 2)
        #expect(published.allSatisfy(\.mainThread))
        #expect(finishedCount == 2)
    }
}
