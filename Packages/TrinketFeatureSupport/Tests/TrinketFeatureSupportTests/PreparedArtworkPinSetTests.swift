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

    @Test(arguments: [false, true])
    func `cancelled or invalid presentation releases only its new acquisition`(cancelled: Bool) async {
        let backend = PinBackend()
        let pins = backend.makePinSet()
        await pins.prepare(names: ["visible"])
        backend.pauseNextRequest = true
        var isCurrent = true
        let pending = Task { await pins.prepare(names: ["pending"], isCurrent: { isCurrent }) }
        await backend.waitForRequest()
        if cancelled {
            pending.cancel()
        } else {
            isCurrent = false
        }
        backend.completeRequest()
        #expect(await pending.value == nil)
        #expect(pins.names == ["visible"])
        #expect(backend.counts == ["visible": 1])
        pins.release()
        #expect(backend.counts.isEmpty)
    }

    @Test(arguments: [false, true])
    func `rejected preparation preserves a current pending acquisition`(cancelled: Bool) async {
        let backend = PinBackend()
        let pins = backend.makePinSet()
        await pins.prepare(names: ["visible"])
        backend.pauseNextRequest = true
        let current = Task { await pins.prepare(names: ["replacement"]) }
        await backend.waitForRequest()

        let rejected = Task { await pins.prepare(names: ["rejected"], isCurrent: { cancelled }) }
        if cancelled {
            rejected.cancel()
        }
        #expect(await rejected.value == nil)
        backend.completeRequest()

        #expect(await current.value != nil)
        #expect(pins.names == ["replacement"])
        #expect(backend.counts == ["replacement": 1])
        pins.release()
        #expect(backend.counts.isEmpty)
    }

    @Test(arguments: [false, true])
    func `rejected preparation preserves a current crossfade completion`(cancelled: Bool) async throws {
        let backend = PinBackend()
        let pins = backend.makePinSet()
        await pins.prepare(names: ["outgoing"])
        let current = try #require(await pins.prepare(names: ["incoming"], retainingOutgoing: true))

        let rejected = Task { await pins.prepare(names: ["rejected"], isCurrent: { cancelled }) }
        if cancelled {
            rejected.cancel()
        }
        #expect(await rejected.value == nil)

        #expect(pins.finish(current))
        #expect(pins.names == ["incoming"])
        #expect(backend.counts == ["incoming": 1])
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
