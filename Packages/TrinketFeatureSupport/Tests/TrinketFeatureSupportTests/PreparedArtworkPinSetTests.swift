import Foundation
import Testing
@testable import TrinketFeatureSupport

@MainActor
struct PreparedArtworkPinSetTests {
    @Test(arguments: [false, true])
    func `teardown releases only its own remaining pins`(releaseFirst: Bool) async {
        let backend = PinBackend()
        var departing: PreparedArtworkPinSet? = backend.makePinSet()
        let remaining = backend.makePinSet()
        await departing?.prepare(names: ["shared", "departing"])
        await remaining.prepare(names: ["shared"])
        if releaseFirst {
            departing?.release()
        }
        weak let released = departing
        departing = nil
        #expect(released == nil)
        #expect(backend.counts == ["shared": 1])
        remaining.release()
        #expect(backend.counts.isEmpty)
    }

    @Test func `leaving during preparation cannot release a returning surface's pins`() async {
        let backend = PinBackend()
        let pins = backend.makePinSet()
        await pins.prepare(names: ["shared", "old"])

        backend.pauseNextRequest = true
        let obsolete = Task { await pins.prepare(names: ["shared", "late"]) }
        await backend.waitForRequest()
        pins.release()
        await pins.prepare(names: ["shared", "new"])
        backend.completeRequest()
        #expect(await obsolete.value == nil)
        #expect(pins.names == ["shared", "new"])
        #expect(backend.counts == ["shared": 1, "new": 1])

        pins.release()
        #expect(backend.counts.isEmpty)
    }

    @Test func `overlapping preparation and obsolete fades cannot unpin the latest artwork`() async throws {
        let backend = PinBackend()
        let pins = backend.makePinSet()
        await pins.prepare(names: ["old"])
        let firstFade = try #require(await pins.prepare(names: ["middle"], retainingOutgoing: true))

        backend.pauseNextRequest = true
        let obsolete = Task { await pins.prepare(names: ["shared"]) }
        await backend.waitForRequest()
        let latestFade = try #require(await pins.prepare(names: ["shared", "new"], retainingOutgoing: true))
        backend.completeRequest()
        #expect(await obsolete.value == nil)
        #expect(!pins.finish(firstFade))
        #expect(backend.counts == ["old": 1, "middle": 1, "shared": 1, "new": 1])

        #expect(pins.finish(latestFade))
        #expect(backend.counts == ["shared": 1, "new": 1])
        pins.release()
        #expect(backend.counts.isEmpty)
    }

    @Test func `cancelled or invalid presentation releases only its new acquisition`() async {
        let backend = PinBackend()
        let pins = backend.makePinSet()
        await pins.prepare(names: ["visible"])
        backend.pauseNextRequest = true
        let cancelled = Task { await pins.prepare(names: ["cancelled"]) }
        await backend.waitForRequest()
        cancelled.cancel()
        backend.completeRequest()
        #expect(await cancelled.value == nil)
        #expect(await pins.prepare(names: ["stale"], isCurrent: { false }) == nil)
        #expect(pins.names == ["visible"])
        #expect(backend.counts == ["visible": 1])
        pins.release()
        #expect(backend.counts.isEmpty)
    }
}

@MainActor
private final class PinBackend {
    var pauseNextRequest = false
    private(set) var counts: [String: Int] = [:]
    private var pending: CheckedContinuation<Void, Never>?
    private var requestWaiter: CheckedContinuation<Void, Never>?

    func makePinSet() -> PreparedArtworkPinSet {
        PreparedArtworkPinSet(acquire: { names in
            if self.pauseNextRequest {
                self.pauseNextRequest = false
                await withCheckedContinuation { continuation in
                    self.pending = continuation
                    self.requestWaiter?.resume()
                    self.requestWaiter = nil
                }
            }
            for name in names {
                self.counts[name, default: 0] += 1
            }
            return names
        }, release: { names in
            for name in names {
                let count = self.counts[name, default: 0]
                #expect(count > 0, "An owner must never release another owner's pin")
                self.counts[name] = count > 1 ? count - 1 : nil
            }
        })
    }

    func waitForRequest() async {
        guard pending == nil else { return }
        await withCheckedContinuation { requestWaiter = $0 }
    }

    func completeRequest() {
        let continuation = pending
        pending = nil
        continuation?.resume()
    }
}
