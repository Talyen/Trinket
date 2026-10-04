import Testing
import TrinketContent
import UIKit
@testable import TrinketFeatureSupport

@MainActor
struct PreparedArtworkCacheTests {
    @Test func `warmup plan puts priority names first and preserves catalog order`() {
        let plan = LaunchArtworkWarmupPlan.make(
            priorityImageNames: ["hero", "enemy", "missing"],
            catalogNames: ["a", "enemy", "b", "hero", "c"],
        )

        #expect(plan.priorityNames == ["enemy", "hero"])
        #expect(plan.deferredNames == ["a", "b", "c"])
    }

    @Test func `prepare all releases launch before deferred catalog finishes`() async throws {
        let deferredGate = DeferredDecodeGate()
        defer { Task { await deferredGate.open() } }
        let cache = PreparedArtworkCache.makeForTesting(
            catalogNames: ["priority-a", "priority-b", "deferred-a", "deferred-b"],
        ) { name in
            if name.hasPrefix("deferred-") {
                await deferredGate.waitUntilOpen()
            }
            return PreparedArtwork(name: name, image: nil)
        }

        var launchReleased = false
        let prepareTask = Task {
            await cache.prepareAll(priorityImageNames: ["priority-a", "priority-b"])
            launchReleased = true
        }
        defer { prepareTask.cancel() }

        try await waitUntil("launch preparation to release before deferred decoding") { launchReleased }

        #expect(cache.isLaunchWarmupComplete)
        #expect(!cache.isDeferredWarmupComplete)
        #expect(cache.completedCount == 2)

        await deferredGate.open()
        await cache.waitForDeferredWarmup()

        #expect(cache.isDeferredWarmupComplete)
        #expect(cache.completedCount == 4)
    }

    @Test func `viewport prepare overtakes queued deferred artwork`() async throws {
        let image = makeImage()
        let deferredGate = DeferredDecodeGate()
        defer { Task { await deferredGate.open() } }
        let blockedStarts = DecodeCallCounter()
        let cache = PreparedArtworkCache.makeForTesting(
            catalogNames: ["blocked-a", "blocked-b", "viewport"],
        ) { name in
            if name.hasPrefix("blocked-") {
                await blockedStarts.markCalled()
                await deferredGate.waitUntilOpen()
            }
            return PreparedArtwork(name: name, image: image)
        }

        await cache.prepareAll(priorityImageNames: [])
        try await waitUntil("the first deferred decode") { await blockedStarts.count >= 1 }
        let viewport = Task { await cache.prepare(names: ["viewport"]) }
        defer { viewport.cancel() }
        try await waitUntil("viewport artwork while deferred decoding is blocked") {
            cache.image(named: "viewport") != nil
        }

        #expect(await blockedStarts.count == 1)

        await deferredGate.open()
        await viewport.value
        await cache.waitForDeferredWarmup()
    }

    @Test func `background thumbnails participate in default warmup catalog`() throws {
        let reference = try #require(
            ArtCatalog.backgroundArtByID.values.first { $0.thumbnailImageName != nil },
        )
        let thumbnail = try #require(reference.thumbnailImageName)

        #expect(PreparedArtworkCache.defaultPresentationImageNames.contains(reference.imageName))
        #expect(PreparedArtworkCache.defaultPresentationImageNames.contains(thumbnail))
    }

    @Test func `concurrent callers share two decode slots and canceled queued pins are balanced`() async throws {
        let probe = DecodeProbe()
        defer { Task { await probe.releaseAll() } }
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: []) { name in
            await probe.decode(name)
        }
        let first = Task { await cache.prepare(names: ["a", "b"]) }
        defer { first.cancel() }
        try await waitUntil("both initial decode slots") { await probe.started.count >= 2 }
        let canceled = Task { _ = await cache.prepareAndPin(names: ["c"]) }
        defer { canceled.cancel() }
        let pinned = Task { _ = await cache.prepareAndPin(names: ["d", "e"]) }
        defer { pinned.cancel() }
        try await waitUntil("queued pin demand for c and e") {
            cache.pinDemandCount(for: "c") > 0 && cache.pinDemandCount(for: "e") > 0
        }
        // Both decode slots run concurrently, so "a"/"b" arrival order is
        // unsynchronized; only the started set is deterministic here.
        let initiallyStarted = await probe.started
        #expect(Set(initiallyStarted) == Set(["a", "b"]))
        canceled.cancel()
        try await waitUntil("canceled queued pin demand to release") { cache.pinDemandCount(for: "c") == 0 }
        await canceled.value
        await probe.release("a")
        try await waitUntil("the promoted d decode") { await probe.started.count >= 3 }
        let startedAfterRelease = await probe.started
        #expect(startedAfterRelease.count == 3)
        #expect(Set(startedAfterRelease.dropLast()) == Set(["a", "b"]))
        #expect(startedAfterRelease.last == "d")
        await probe.release("b")
        try await waitUntil("the queued e decode") { await probe.started.count >= 4 }
        await probe.release("d")
        await probe.release("e")
        await first.value
        await pinned.value
        #expect(await probe.maximumActive == 2)
    }

    @Test func `imminent demand promotes deferred work ahead of queued viewport work`() async throws {
        let probe = DecodeProbe()
        defer { Task { await probe.releaseAll() } }
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: ["a", "z"]) { name in
            await probe.decode(name)
        }
        await cache.prepareAll(priorityImageNames: [])
        try await waitUntil("the initial deferred decode") { await probe.started.count >= 1 }
        let viewport = Task { await cache.prepare(names: ["b", "c"]) }
        defer { viewport.cancel() }
        try await waitUntil("the viewport b decode") { await probe.started.count >= 2 }
        let imminent = Task { _ = await cache.prepareAndPin(names: ["z"]) }
        defer { imminent.cancel() }
        try await waitUntil("imminent pin demand for z") { cache.pinDemandCount(for: "z") > 0 }
        await probe.release("b")
        try await waitUntil("the promoted z decode") { await probe.started.count >= 3 }
        #expect(await probe.started == ["a", "b", "z"])
        await probe.release("z")
        try await waitUntil("the queued c decode") { await probe.started.count >= 4 }
        await probe.release("a")
        await probe.release("c")
        await viewport.value
        await imminent.value
        await cache.waitForDeferredWarmup()
        #expect(await probe.maximumActive == 2)
        #expect(await probe.started.count(where: { $0 == "z" }) == 1)
    }

    @Test func `portrait backgrounds are prepared by their owning surface`() {
        let portraits = Set(ArtCatalog.portraitBackgroundArtByID.values.map(\.imageName))
        #expect(!portraits.isEmpty)
        #expect(portraits.isDisjoint(with: PreparedArtworkCache.defaultPresentationImageNames))
        #expect(portraits.isSubset(of: ArtCatalog.allImageNamesSet))
    }

    @Test func `snapshots include artwork prepared after launch`() async {
        let image = makeImage()
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: []) { name in
            PreparedArtwork(name: name, image: image)
        }
        await cache.prepareAll(priorityImageNames: [])
        await cache.waitForDeferredWarmup()
        _ = await cache.prepareAndPin(names: ["portrait"])
        #expect(cache.snapshot().residentCount == 1)
        #expect(cache.snapshot().pinnedCount == 1)
        #expect(cache.snapshot().residentByteCount > 0)
        cache.releasePins(names: ["portrait"])
        #expect(cache.snapshot().pinnedCount == 0)
    }

    @Test func `launch warmup snapshot reports resident and pinned decoded images`() async {
        let image = makeImage()
        let preparedByName = [
            "priority": PreparedArtwork(name: "priority", image: image),
            "deferred": PreparedArtwork(name: "deferred", image: image),
        ]
        let cache = PreparedArtworkCache.makeForTesting(
            catalogNames: ["priority", "deferred"],
        ) { name in
            preparedByName[name] ?? PreparedArtwork(name: name, image: nil)
        }

        await cache.prepareAll(priorityImageNames: ["priority"])
        await cache.waitForDeferredWarmup()
        let snapshot = cache.snapshot()

        #expect(snapshot.requestedCount == 2)
        #expect(snapshot.residentCount == 2)
        #expect(snapshot.nonresidentCount == 0)
        #expect(snapshot.residentByteCount > 0)
        #expect(snapshot.pinnedCount == 1)
        #expect(snapshot.pinnedByteCount > 0)
    }

    @Test func `prepare and pin retries artwork that is not resident`() async {
        let image = makeImage()
        let source = RetryingDecodeSource(image: image)
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: ["art"]) { name in
            await source.decode(name: name)
        }

        await cache.prepareAll(priorityImageNames: ["art"])
        _ = await cache.prepareAndPin(names: ["art"])

        let attemptCount = await source.attemptCount
        #expect(attemptCount == 2)
        #expect(cache.snapshot().pinnedCount == 1)
        #expect(cache.pinDemandCount(for: "art") == 1)

        cache.releasePins(names: ["art"])

        #expect(cache.snapshot().pinnedCount == 0)
        #expect(cache.image(named: "art") != nil)

        cache.releasePins(names: ["art"])
        #expect(cache.snapshot().pinnedCount == 0)
    }

    @Test func `overlapping pins remain resident until every owner releases`() async {
        let image = makeImage()
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: ["art"]) { name in
            PreparedArtwork(name: name, image: image)
        }

        await cache.prepareAll(priorityImageNames: ["art"])
        _ = await cache.prepareAndPin(names: ["art"])
        _ = await cache.prepareAndPin(names: ["art"])
        cache.releasePins(names: ["art"])

        #expect(cache.snapshot().pinnedCount == 1)
        #expect(cache.image(named: "art") != nil)

        cache.releasePins(names: ["art"])
        #expect(cache.snapshot().pinnedCount == 1)

        cache.releasePins(names: ["art"])
        #expect(cache.snapshot().pinnedCount == 0)
    }

    @Test func `cloud artwork handoff retains old pins until publication and releases discarded pins`() async {
        let image = makeImage()
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: ["old", "shared", "new"]) { name in
            PreparedArtwork(name: name, image: image)
        }
        await cache.prepareAll(priorityImageNames: ["old", "shared"])

        let discard = await cache.prepareLaunchPinReplacement(names: ["shared", "new"])
        #expect(cache.pinDemandCount(for: "old") == 1)
        #expect(cache.pinDemandCount(for: "shared") == 2)
        #expect(cache.pinDemandCount(for: "new") == 1)
        discard(false)
        #expect(cache.pinDemandCount(for: "old") == 1)
        #expect(cache.pinDemandCount(for: "shared") == 1)
        #expect(cache.pinDemandCount(for: "new") == 0)

        let publish = await cache.prepareLaunchPinReplacement(names: ["shared", "new"])
        publish(true)
        #expect(cache.pinDemandCount(for: "old") == 0)
        #expect(cache.pinDemandCount(for: "shared") == 1)
        #expect(cache.pinDemandCount(for: "new") == 1)
    }
}

extension PreparedArtworkCacheTests {
    @Test func `releasing pins during decode does not leak A pin`() async throws {
        let image = makeImage()
        let gate = DeferredDecodeGate()
        defer { Task { await gate.open() } }
        let started = DecodeCallCounter()
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: ["art"]) { name in
            await started.markCalled()
            await gate.waitUntilOpen()
            return PreparedArtwork(name: name, image: image)
        }

        let prepareTask = Task { _ = await cache.prepareAndPin(names: ["art"]) }
        defer { prepareTask.cancel() }
        try await waitUntil("the pinned artwork decode") { await started.count >= 1 }
        cache.releasePins(names: ["art"])
        await gate.open()
        await prepareTask.value

        #expect(cache.snapshot().pinnedCount == 0)
        #expect(cache.image(named: "art") != nil)
    }

    @Test func `priority pins materialize when artwork is already cached`() async {
        let image = makeImage()
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: ["priority"]) { name in
            PreparedArtwork(name: name, image: image)
        }

        await cache.prepare(names: ["priority"])
        await cache.prepareAll(priorityImageNames: ["priority"])
        await cache.waitForDeferredWarmup()

        #expect(cache.snapshot().pinnedCount == 1)

        cache.releasePins(names: ["priority"])
        #expect(cache.snapshot().pinnedCount == 0)
        #expect(cache.image(named: "priority") != nil)
    }

    @Test func `failed priority warmup leaves no phantom demand`() async {
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: ["art"]) { name in
            PreparedArtwork(name: name, image: nil)
        }

        await cache.prepareAll(priorityImageNames: ["art"])
        #expect(cache.pinDemandCount(for: "art") == 0)
        #expect(cache.snapshot().pinnedCount == 0)
    }

    @Test(arguments: [false, true])
    func `shared decode survives consumer cancellation`(cancelInitiator: Bool) async throws {
        let image = makeImage()
        let gate = DeferredDecodeGate()
        defer { Task { await gate.open() } }
        let counter = DecodeCallCounter()
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: ["art"]) { name in
            await counter.markCalled()
            await gate.waitUntilOpen()
            return PreparedArtwork(name: name, image: image)
        }

        let viewport = Task { await cache.prepare(names: ["art"]) }
        defer { viewport.cancel() }
        try await waitUntil("the shared artwork decode") { await counter.count >= 1 }
        let pin = Task { _ = await cache.prepareAndPin(names: ["art"]) }
        defer { pin.cancel() }
        try await waitUntil("the shared artwork pin") { cache.pinDemandCount(for: "art") == 1 }

        if cancelInitiator {
            viewport.cancel()
        } else {
            pin.cancel()
        }
        await gate.open()
        await viewport.value
        await pin.value

        #expect(await counter.count == 1)
        #expect(cache.image(named: "art") != nil)
        #expect(cache.snapshot().pinnedCount == 1)
        #expect(cache.pinDemandCount(for: "art") == 1)
        cache.releasePins(names: ["art"])
        #expect(cache.snapshot().pinnedCount == 0)
        #expect(cache.pinDemandCount(for: "art") == 0)
    }

    @Test func `canceled batch finishes started images without decoding queued images`() async throws {
        let image = makeImage()
        let gate = DeferredDecodeGate()
        defer { Task { await gate.open() } }
        let counter = DecodeCallCounter()
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: []) { name in
            await counter.markCalled()
            await gate.waitUntilOpen()
            return PreparedArtwork(name: name, image: image)
        }

        let batch = Task { await cache.prepare(names: ["a", "b", "c", "d"]) }
        defer { batch.cancel() }
        try await waitUntil("both batch decode slots") { await counter.count >= 2 }
        batch.cancel()
        await gate.open()
        await batch.value

        #expect(await counter.count == 2)
        #expect(cache.image(named: "a") != nil)
        #expect(cache.image(named: "b") != nil)
        #expect(cache.image(named: "c") == nil)
        #expect(cache.image(named: "d") == nil)
    }

    @Test func `canceled cached pin acquisition does not release another owners demand`() async {
        let image = makeImage()
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: ["art"]) { name in
            PreparedArtwork(name: name, image: image)
        }
        _ = await cache.prepareAndPin(names: ["art"])
        let canceled = Task {
            let acquired = await cache.prepareAndPin(names: ["art"])
            cache.releasePins(names: acquired)
        }
        canceled.cancel()
        await canceled.value
        #expect(cache.pinDemandCount(for: "art") == 1)
        #expect(cache.snapshot().pinnedCount == 1)
        cache.releasePins(names: ["art"])
    }

    @Test func `already canceled batch does not decode or leave pin demand`() async {
        let counter = DecodeCallCounter()
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: []) { name in
            await counter.markCalled()
            return PreparedArtwork(name: name, image: nil)
        }

        let batch = Task {
            _ = await cache.prepareAndPin(names: ["art"])
        }
        batch.cancel()
        await batch.value

        let attemptedDecodes = await counter.count
        #expect(attemptedDecodes == 0)
        #expect(cache.pinDemandCount(for: "art") == 0)
    }

    private func waitUntil(_ description: String, condition: @MainActor () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while true {
            try Task.checkCancellation()
            if await condition() {
                return
            }
            try #require(ContinuousClock.now < deadline, "Timed out waiting for \(description)")
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.red.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }
}

extension PreparedArtworkCacheTests {
    @Test func `failed pin receipt cannot release a later successful owners artwork`() async {
        let source = RetryingDecodeSource(image: makeImage())
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: []) { name in
            await source.decode(name: name)
        }
        let failed = await cache.prepareAndPin(names: ["art"])
        #expect(failed.isEmpty)
        #expect(cache.pinDemandCount(for: "art") == 0)
        let acquired = await cache.prepareAndPin(names: ["art"])
        #expect(acquired == ["art"])

        cache.releasePins(names: failed)
        #expect(cache.pinDemandCount(for: "art") == 1)
        #expect(cache.snapshot().pinnedCount == 1)
        cache.releasePins(names: acquired)
        #expect(cache.pinDemandCount(for: "art") == 0)
    }
}

private actor RetryingDecodeSource {
    private(set) var attemptCount = 0
    let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    func decode(name: String) -> PreparedArtwork {
        attemptCount += 1
        return PreparedArtwork(name: name, image: attemptCount == 1 ? nil : image)
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

private actor DecodeCallCounter {
    private(set) var count = 0

    func markCalled() {
        count += 1
    }
}

private actor DecodeProbe {
    private(set) var started: [String] = []
    private(set) var maximumActive = 0
    private var pending: [String: CheckedContinuation<Void, Never>] = [:]
    private var isReleased = false

    func decode(_ name: String) async -> PreparedArtwork {
        if !isReleased {
            await withCheckedContinuation { continuation in
                pending[name] = continuation
                started.append(name)
                maximumActive = max(maximumActive, pending.count)
            }
        }
        return PreparedArtwork(name: name, image: nil)
    }

    func release(_ name: String) {
        pending.removeValue(forKey: name)?.resume()
    }

    func releaseAll() {
        isReleased = true
        let decodes = pending.values
        pending.removeAll()
        for decode in decodes {
            decode.resume()
        }
    }
}
