import Observation
import SwiftUI
import TrinketContent
import UIKit

/// Ordered launch warmup buckets: priority assets decode first, followed by the
/// remainder of the catalog before interactive content is presented.
struct LaunchArtworkWarmupPlan: Equatable {
    let priorityNames: [String]
    let deferredNames: [String]

    /// Priority names that exist in the catalog come first; remaining catalog names are deferred.
    /// Catalog order is preserved within each bucket.
    static func make(priorityImageNames: [String], catalogNames: [String]) -> LaunchArtworkWarmupPlan {
        let priority = Set(priorityImageNames)
        return LaunchArtworkWarmupPlan(
            priorityNames: catalogNames.filter { priority.contains($0) },
            deferredNames: catalogNames.filter { !priority.contains($0) }
        )
    }
}

/// App-wide eager artwork preparation. The launch completion contract means the
/// entire presentation catalog is decoded, so navigation and combat never inherit
/// background preparation work from launch.
@MainActor
@Observable
final class PreparedArtworkCache {
    static let shared = PreparedArtworkCache()

    private(set) var completedCount = 0
    private(set) var totalCount = 1
    private(set) var isLaunchWarmupComplete = false

    /// True once the complete catalog decode has finished.
    private(set) var isDeferredWarmupComplete = false

    @ObservationIgnored private let images = NSCache<NSString, UIImage>()
    /// Launch-critical bitmaps are a deliberately small strong set. Keeping them
    /// outside NSCache prevents the full-catalog warmup from evicting the exact
    /// images needed by the first interactive transitions.
    @ObservationIgnored private var pinnedImages: [String: UIImage] = [:]
    @ObservationIgnored private var pinnedNames: Set<String> = []
    @ObservationIgnored private var launchWarmupTask: Task<Void, Never>?
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

    var progress: Double {
        min(Double(completedCount) / Double(max(totalCount, 1)), 1)
    }

    func image(named name: String) -> UIImage? {
        pinnedImages[name] ?? images.object(forKey: name as NSString)
    }

    func prepareAll(priorityImageNames: [String]) async {
        if isLaunchWarmupComplete {
            return
        }
        if let launchWarmupTask {
            await launchWarmupTask.value
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
            guard !Task.isCancelled else { return }
            await decode(plan.deferredNames, maximumConcurrency: 2, countsTowardLaunch: true)
            guard !Task.isCancelled else { return }
            isDeferredWarmupComplete = true
            isLaunchWarmupComplete = true
            completedCount = totalCount
            launchWarmupTask = nil
        }
        launchWarmupTask = task
        await task.value
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
private final class DecodeBox: @unchecked Sendable {
    let decode: @Sendable (String) async -> PreparedArtwork

    init(_ decode: @escaping @Sendable (String) async -> PreparedArtwork) {
        self.decode = decode
    }
}

struct PreparedArtwork: @unchecked Sendable {
    let name: String
    let image: UIImage?
}

extension Image {
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

extension View {
    /// Marks prepared catalog art as decorative when a parent control owns accessibility.
    func decorativePreparedArtwork() -> some View {
        accessibilityHidden(true)
    }
}
