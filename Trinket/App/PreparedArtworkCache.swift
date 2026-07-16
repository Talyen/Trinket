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
    static func make(priorityImageNames: [String], catalogNames: [String]) -> LaunchArtworkWarmupPlan {
        let priority = Set(priorityImageNames)
        return LaunchArtworkWarmupPlan(
            priorityNames: catalogNames.filter { priority.contains($0) },
            deferredNames: catalogNames.filter { !priority.contains($0) }
        )
    }
}

/// Decodes catalog artwork before interactive UI appears. The cache is deliberately
/// cost-bounded: the launch pass warms priority assets first so UI can appear, then
/// continues decoding the rest without risking an unbounded decoded-image footprint.
@MainActor
@Observable
final class PreparedArtworkCache {
    static let shared = PreparedArtworkCache()

    private(set) var completedCount = 0
    private(set) var totalCount = 1
    private(set) var isLaunchWarmupComplete = false

    /// True once deferred catalog decode has finished (or there was nothing deferred).
    private(set) var isDeferredWarmupComplete = false

    @ObservationIgnored private let images = NSCache<NSString, UIImage>()
    @ObservationIgnored private var warmupTask: Task<Void, Never>?
    @ObservationIgnored private let catalogNamesProvider: () -> [String]
    @ObservationIgnored private let decodeBox: DecodeBox

    private init() {
        catalogNamesProvider = { Self.defaultPresentationImageNames }
        decodeBox = DecodeBox { await Self.decodeImage(named: $0) }
        configureImageBudget()
    }

    private init(
        catalogNamesProvider: @escaping () -> [String],
        decodeHandler: @escaping @Sendable (String) async -> PreparedArtwork
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
            decodeHandler: decode
        )
    }

    var progress: Double {
        min(Double(completedCount) / Double(max(totalCount, 1)), 1)
    }

    func image(named name: String) -> UIImage? {
        images.object(forKey: name as NSString)
    }

    func prepareAll(priorityImageNames: [String]) async {
        if isLaunchWarmupComplete, isDeferredWarmupComplete {
            return
        }
        if let warmupTask {
            await warmupTask.value
            return
        }

        let plan = LaunchArtworkWarmupPlan.make(
            priorityImageNames: priorityImageNames,
            catalogNames: catalogNamesProvider()
        )
        totalCount = max(plan.priorityNames.count + plan.deferredNames.count, 1)
        completedCount = 0
        isDeferredWarmupComplete = false

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            // Unblock interactive UI after the critical path; keep decoding the rest
            // so later screens still hit the warm cache without stalling launch.
            await decode(plan.priorityNames)
            isLaunchWarmupComplete = true
            await decode(plan.deferredNames)
            isDeferredWarmupComplete = true
            warmupTask = nil
        }
        warmupTask = task
        await task.value
    }

    private func decode(_ imageNames: [String]) async {
        let decoder = decodeBox
        await withTaskGroup(of: PreparedArtwork.self) { group in
            var iterator = imageNames.makeIterator()
            let maximumConcurrentDecodes = 4

            for _ in 0 ..< maximumConcurrentDecodes {
                guard let name = iterator.next() else { break }
                group.addTask { await decoder.decode(name) }
            }

            while let prepared = await group.next() {
                if let image = prepared.image {
                    images.setObject(
                        image,
                        forKey: prepared.name as NSString,
                        cost: Self.decodedCost(of: image)
                    )
                }
                completedCount += 1

                if let name = iterator.next() {
                    group.addTask { await decoder.decode(name) }
                }
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
