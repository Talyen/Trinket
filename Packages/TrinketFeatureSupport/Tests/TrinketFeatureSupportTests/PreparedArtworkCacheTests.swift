import Testing
import TrinketContent
import UIKit
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

    @Test func prepareAllReleasesLaunchBeforeDeferredCatalogFinishes() async {
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

        await prepareTask.value

        #expect(cache.isLaunchWarmupComplete)
        #expect(!cache.isDeferredWarmupComplete)
        #expect(cache.completedCount == 2)

        await deferredGate.open()
        await cache.waitForDeferredWarmup()

        #expect(cache.isDeferredWarmupComplete)
        #expect(cache.completedCount == 4)
    }

    @Test func backgroundThumbnailsParticipateInDefaultWarmupCatalog() throws {
        let reference = try #require(
            ArtCatalog.backgroundArtByID.values.first { $0.thumbnailImageName != nil }
        )
        let thumbnail = try #require(reference.thumbnailImageName)

        #expect(PreparedArtworkCache.defaultPresentationImageNames.contains(reference.imageName))
        #expect(PreparedArtworkCache.defaultPresentationImageNames.contains(thumbnail))
    }

    @Test func launchWarmupSnapshotReportsResidentAndPinnedDecodedImages() async {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.red.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let preparedByName = [
            "priority": PreparedArtwork(name: "priority", image: image),
            "deferred": PreparedArtwork(name: "deferred", image: image),
        ]
        let cache = PreparedArtworkCache.makeForTesting(
            catalogNames: ["priority", "deferred"]
        ) { name in
            preparedByName[name] ?? PreparedArtwork(name: name, image: nil)
        }

        await cache.prepareAll(priorityImageNames: ["priority"])
        await cache.waitForDeferredWarmup()
        let snapshot = cache.launchWarmupSnapshot()

        #expect(snapshot.requestedCount == 2)
        #expect(snapshot.residentCount == 2)
        #expect(snapshot.nonresidentCount == 0)
        #expect(snapshot.residentByteCount > 0)
        #expect(snapshot.pinnedCount == 1)
        #expect(snapshot.pinnedByteCount > 0)
    }

    @Test func prepareAndPinRetriesArtworkThatIsNotResident() async {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.red.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let source = RetryingDecodeSource(image: image)
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: ["art"]) { name in
            await source.decode(name: name)
        }

        await cache.prepareAll(priorityImageNames: ["art"])
        await cache.prepareAndPin(names: ["art"])

        let attemptCount = await source.attemptCount
        #expect(attemptCount == 2)
        #expect(cache.launchWarmupSnapshot().pinnedCount == 1)

        cache.releasePins(names: ["art"])

        #expect(cache.launchWarmupSnapshot().pinnedCount == 1)
        #expect(cache.image(named: "art") != nil)

        cache.releasePins(names: ["art"])
        #expect(cache.launchWarmupSnapshot().pinnedCount == 0)
    }

    @Test func overlappingPinsRemainResidentUntilEveryOwnerReleases() async {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.red.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let cache = PreparedArtworkCache.makeForTesting(catalogNames: ["art"]) { name in
            PreparedArtwork(name: name, image: image)
        }

        await cache.prepareAll(priorityImageNames: ["art"])
        await cache.prepareAndPin(names: ["art"])
        await cache.prepareAndPin(names: ["art"])
        cache.releasePins(names: ["art"])

        #expect(cache.launchWarmupSnapshot().pinnedCount == 1)
        #expect(cache.image(named: "art") != nil)

        cache.releasePins(names: ["art"])
        #expect(cache.launchWarmupSnapshot().pinnedCount == 1)

        cache.releasePins(names: ["art"])
        #expect(cache.launchWarmupSnapshot().pinnedCount == 0)
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
