import Observation
import SwiftUI
import TrinketContent
import UIKit

/// Ordered launch warmup buckets: priority assets unblock UI; deferred assets fill the cache.
struct LaunchArtworkWarmupPlan: Equatable {
    let priorityNames: [String]
    let deferredNames: [String]

    /// Priority names that exist in the catalog come first; remaining catalog names are deferred.
    /// Catalog order is preserved within each bucket.
    static func make(priorityImageNames: [String], catalogNames: [String]) -> Self {
        let priority = Set(priorityImageNames)
        return Self(
            priorityNames: catalogNames.filter { priority.contains($0) },
            deferredNames: catalogNames.filter { !priority.contains($0) }
        )
    }
}

/// App-wide artwork preparation. Priority assets decode first so interactive UI can
/// appear; deferred catalog decode continues in the background without gating launch.
@MainActor
@Observable
public final class PreparedArtworkCache {
    public static let shared = PreparedArtworkCache()

    public private(set) var completedCount = 0
    public private(set) var totalCount = 1
    public private(set) var isLaunchWarmupComplete = false

    /// True once deferred catalog decode has finished (or there was nothing deferred).
    public private(set) var isDeferredWarmupComplete = false

    @ObservationIgnored private let images = NSCache<NSString, UIImage>()
    /// Launch-critical bitmaps are a deliberately small strong set. Keeping them
    /// outside NSCache prevents the full-catalog warmup from evicting the exact
    /// images needed by the first interactive transitions.
    @ObservationIgnored private var pinnedImages: [String: UIImage] = [:]
    @ObservationIgnored private var pinnedNames: Set<String> = []
    @ObservationIgnored private var priorityWarmupTask: Task<Void, Never>?
    @ObservationIgnored private var deferredWarmupTask: Task<Void, Never>?
    @ObservationIgnored private var decodedNames: Set<String> = []
    @ObservationIgnored private let catalogNamesProvider: () -> [String]
    @ObservationIgnored private let decodeBox: DecodeBox

    private init() {
        catalogNamesProvider = { Self.defaultPresentationImageNames }
        decodeBox = DecodeBox { await Self.decodeImage(named: $0) }
        configureImageBudget()
    }

    private init(
        catalogNamesProvider: @escaping () -> [String],
        decodeHandler: @escaping @Sendable (String) async -> PreparedArtwork,
        deferredWarmupDelay _: Duration
    ) {
        self.catalogNamesProvider = catalogNamesProvider
        decodeBox = DecodeBox(decodeHandler)
        configureImageBudget()
    }

    private func configureImageBudget() {
        let physicalMemory = Int(ProcessInfo.processInfo.physicalMemory)
        let adaptiveBudget = physicalMemory / 24
        images.totalCostLimit = min(max(adaptiveBudget, 96 * 1024 * 1024), 256 * 1024 * 1024)
    }

    /// Isolated cache for unit tests (does not touch `shared`).
    static func makeForTesting(
        catalogNames: [String],
        decode: @escaping @Sendable (String) async -> PreparedArtwork = { PreparedArtwork(name: $0, image: nil) }
    ) -> PreparedArtworkCache {
        PreparedArtworkCache(
            catalogNamesProvider: { catalogNames },
            decodeHandler: decode,
            deferredWarmupDelay: .zero
        )
    }

    public var progress: Double {
        min(Double(completedCount) / Double(max(totalCount, 1)), 1)
    }

    public func image(named name: String) -> UIImage? {
        pinnedImages[name] ?? images.object(forKey: name as NSString)
    }

    /// Decode and pin images that must survive NSCache pressure until first use
    /// (for example, opening-hand ability art for an imminent battle).
    public func prepareAndPin(names: [String]) async {
        let unique = Array(Set(names)).sorted()
        guard !unique.isEmpty else { return }
        pinnedNames.formUnion(unique)
        for name in unique {
            if let image = images.object(forKey: name as NSString) {
                pinnedImages[name] = image
            }
        }
        await decode(unique, maximumConcurrency: 2, countsTowardLaunch: false)
        for name in unique {
            if pinnedImages[name] == nil,
               let image = images.object(forKey: name as NSString) {
                pinnedImages[name] = image
            }
        }
    }

    public func prepareAll(priorityImageNames: [String]) async {
        if isLaunchWarmupComplete {
            return
        }
        if let priorityWarmupTask {
            await priorityWarmupTask.value
            return
        }

        let plan = LaunchArtworkWarmupPlan.make(
            priorityImageNames: priorityImageNames,
            catalogNames: catalogNamesProvider()
        )
        totalCount = max(plan.priorityNames.count + plan.deferredNames.count, 1)
        completedCount = 0
        isDeferredWarmupComplete = false
        pinnedNames.formUnion(plan.priorityNames)

        let task = Task(priority: .userInitiated) { @MainActor [weak self] in
            guard let self else { return }
            await decode(plan.priorityNames, maximumConcurrency: 2, countsTowardLaunch: true)
            isLaunchWarmupComplete = true
        }
        priorityWarmupTask = task
        await task.value

        deferredWarmupTask = Task(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }
            await decode(plan.deferredNames, maximumConcurrency: 2, countsTowardLaunch: true)
            isDeferredWarmupComplete = true
            completedCount = totalCount
        }
    }

    private func decode(
        _ imageNames: [String],
        maximumConcurrency: Int,
        countsTowardLaunch: Bool
    ) async {
        let decoder = decodeBox
        await withTaskGroup(of: PreparedArtwork.self) { group in
            var iterator = imageNames.filter { !decodedNames.contains($0) }.makeIterator()

            for _ in 0 ..< maximumConcurrency {
                guard let name = iterator.next() else { break }
                group.addTask { await decoder.decode(name) }
            }

            while let prepared = await group.next() {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return
                }
                if let image = prepared.image {
                    images.setObject(
                        image,
                        forKey: prepared.name as NSString,
                        cost: Self.decodedCost(of: image)
                    )
                    if pinnedNames.contains(prepared.name) {
                        pinnedImages[prepared.name] = image
                    }
                }
                decodedNames.insert(prepared.name)
                if countsTowardLaunch {
                    completedCount += 1
                }

                if let name = iterator.next() {
                    group.addTask { await decoder.decode(name) }
                }
                await Task.yield()
            }
        }
    }

    nonisolated static func decodeImage(named name: String) async -> PreparedArtwork {
        guard let source = UIImage(named: name) else {
            return PreparedArtwork(name: name, image: nil)
        }
        let prepared = await source.byPreparingForDisplay()
        return PreparedArtwork(name: name, image: prepared)
    }

    nonisolated static func decodedCost(of image: UIImage) -> Int {
        guard let image = image.cgImage else { return 0 }
        return image.bytesPerRow * image.height
    }

    private static var defaultPresentationImageNames: [String] {
        var names = Set<String>()

        for reference in ArtCatalog.combatantArtByID.values {
            names.insert(reference.imageName)
            if let thumbnailImageName = reference.thumbnailImageName {
                names.insert(thumbnailImageName)
            }
        }
        for reference in ArtCatalog.abilityArtByID.values {
            names.insert(reference.imageName)
        }
        for reference in ArtCatalog.itemArtByID.values {
            names.insert(reference.imageName)
            if let thumbnailImageName = reference.thumbnailImageName {
                names.insert(thumbnailImageName)
            }
        }
        for reference in ArtCatalog.slotBackgroundArtByID.values {
            names.insert(reference.imageName)
        }
        for reference in ArtCatalog.backgroundArtByID.values {
            names.insert(reference.imageName)
        }
        for reference in ArtCatalog.encounterArtByID.values {
            names.insert(reference.imageName)
            if let thumbnailImageName = reference.thumbnailImageName {
                names.insert(thumbnailImageName)
            }
        }
        for reference in ArtCatalog.resourceArtByID.values {
            names.insert(reference.imageName)
        }

        return names.sorted()
    }
}

/// Sendable decode seam so concurrent warmup tasks never capture MainActor state.
///
/// Concurrency-Safety: checked `Sendable` — only stores an already-`@Sendable`
/// decode closure; task-group workers call that closure without capturing
/// `PreparedArtworkCache` MainActor state.
private final class DecodeBox: Sendable {
    let decode: @Sendable (String) async -> PreparedArtwork

    init(_ decode: @escaping @Sendable (String) async -> PreparedArtwork) {
        self.decode = decode
    }
}

/// Concurrency-Safety: `@unchecked Sendable` — `name` is a value type and
/// `image` is immutable after `byPreparingForDisplay()`; task-group workers only
/// produce instances that the MainActor cache then retains.
struct PreparedArtwork: @unchecked Sendable {
    let name: String
    let image: UIImage?
}

public extension Image {
    /// Catalog artwork that prefers the launch-prepared bitmap cache.
    ///
    /// UIImage-backed prepared images become VoiceOver / XCUITest hits unless marked
    /// decorative. After `.resizable()` / framing, chain `.accessibilityHidden(true)`
    /// (or `.decorativePreparedArtwork()`) unless this image *is* the accessibility element.
    @MainActor
    static func preparedAsset(named name: String) -> Image {
        if let image = PreparedArtworkCache.shared.image(named: name) {
            Image(uiImage: image)
        } else {
            Image(name)
        }
    }
}

public extension View {
    /// Marks prepared catalog art as decorative when a parent control owns accessibility.
    func decorativePreparedArtwork() -> some View {
        accessibilityHidden(true)
    }
}
