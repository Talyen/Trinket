import Observation
import SwiftUI
import TrinketContent
import UIKit

/// Decodes catalog artwork before interactive UI appears. The cache is deliberately
/// cost-bounded: the launch pass warms every referenced asset, while the most relevant
/// prepared bitmaps remain resident without risking an unbounded decoded-image footprint.
@MainActor
@Observable
final class PreparedArtworkCache {
    static let shared = PreparedArtworkCache()

    private(set) var completedCount = 0
    private(set) var totalCount = 1
    private(set) var isLaunchWarmupComplete = false

    @ObservationIgnored private let images = NSCache<NSString, UIImage>()
    @ObservationIgnored private var warmupTask: Task<Void, Never>?

    private init() {
        let physicalMemory = Int(ProcessInfo.processInfo.physicalMemory)
        let adaptiveBudget = physicalMemory / 24
        images.totalCostLimit = min(max(adaptiveBudget, 96 * 1024 * 1024), 256 * 1024 * 1024)
    }

    var progress: Double {
        min(Double(completedCount) / Double(max(totalCount, 1)), 1)
    }

    func image(named name: String) -> UIImage? {
        images.object(forKey: name as NSString)
    }

    func prepareAll(priorityImageNames: [String]) async {
        if isLaunchWarmupComplete {
            return
        }
        if let warmupTask {
            await warmupTask.value
            return
        }

        let allNames = Self.allPresentationImageNames
        let priority = Set(priorityImageNames)
        let priorityOrdered = allNames.filter { priority.contains($0) }
        let deferredOrdered = allNames.filter { !priority.contains($0) }
        let orderedNames = priorityOrdered + deferredOrdered
        totalCount = max(orderedNames.count, 1)
        completedCount = 0

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            // Unblock interactive UI after the critical path; keep decoding the rest
            // so later screens still hit the warm cache without stalling launch.
            await decode(priorityOrdered)
            isLaunchWarmupComplete = true
            await decode(deferredOrdered)
            warmupTask = nil
        }
        warmupTask = task
        await task.value
    }

    private func decode(_ imageNames: [String]) async {
        await withTaskGroup(of: PreparedArtwork.self) { group in
            var iterator = imageNames.makeIterator()
            let maximumConcurrentDecodes = 4

            for _ in 0 ..< maximumConcurrentDecodes {
                guard let name = iterator.next() else { break }
                group.addTask { await Self.decodeImage(named: name) }
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
                    group.addTask { await Self.decodeImage(named: name) }
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

    private static var allPresentationImageNames: [String] {
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

struct PreparedArtwork: @unchecked Sendable {
    let name: String
    let image: UIImage?
}

extension Image {
    @MainActor
    static func preparedAsset(named name: String) -> Image {
        if let image = PreparedArtworkCache.shared.image(named: name) {
            Image(uiImage: image)
        } else {
            Image(name)
        }
    }
}
