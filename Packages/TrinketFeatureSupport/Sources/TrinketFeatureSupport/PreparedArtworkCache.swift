import Darwin
import Observation
import os
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

struct PreparedArtworkCacheSnapshot: Equatable, Sendable {
    let requestedCount: Int
    let residentCount: Int
    let residentByteCount: Int
    let pinnedCount: Int
    let pinnedByteCount: Int

    var nonresidentCount: Int {
        max(requestedCount - residentCount, 0)
    }
}

/// Tuned for 6 GB typical (iPhone 14/15/16 base). 6 GB Jetsam kills around
/// 1.4–1.8 GB, 8 GB around 2.0–2.5 GB, so 320/550 is ~5–8% of RAM and 3× under
/// the kill line. Do not lower to re-target 4 GB without product approval.
/// See Docs/Platform/PerformanceInvestigationPlaybook.md § Artwork Budgets.
enum PreparedArtworkMemoryBudget {
    static let residentArtworkByteCount = 320 * 1024 * 1024
    static let steadyStateProcessByteCount = 550 * 1024 * 1024
}

/// App-wide artwork preparation. Priority assets decode before launch releases the
/// interactive UI and stay pinned so deferred catalog warmup cannot evict them;
/// remaining catalog work continues opportunistically afterward. On-demand
/// `Image(name)` on a presentation frame is a hitch, not a memory optimization.
@MainActor
@Observable
public final class PreparedArtworkCache {
    public static let shared = PreparedArtworkCache()

    public private(set) var completedCount = 0
    public private(set) var totalCount = 1
    public private(set) var isLaunchWarmupComplete = false

    /// True once the non-priority catalog decode has finished (or there was none).
    public private(set) var isDeferredWarmupComplete = false

    @ObservationIgnored private let images = NSCache<NSString, UIImage>()
    /// Launch-critical bitmaps are a deliberately small strong set. The app
    /// keeps the first interactive working set pinned so deferred catalog
    /// decode cannot evict it from `NSCache` and force `Image(name)` on a
    /// presentation frame. Transient owners (battle, a visible Collection
    /// sheet) still pin/release around their own lifecycle.
    @ObservationIgnored private var pinnedImages: [String: UIImage] = [:]
    @ObservationIgnored private var pinCountsByName: [String: Int] = [:]
    @ObservationIgnored private var priorityWarmupTask: Task<Void, Never>?
    @ObservationIgnored private var deferredWarmupTask: Task<Void, Never>?
    @ObservationIgnored private var decodedCostsByName: [String: Int] = [:]
    @ObservationIgnored private var launchWarmupNames: [String] = []
    @ObservationIgnored private let catalogNamesProvider: () -> [String]
    @ObservationIgnored private let decodeHandler: @Sendable (String) async -> PreparedArtwork
    @ObservationIgnored private let logger = Logger(
        subsystem: "com.trinket.diagnostics",
        category: "ArtworkCache"
    )

    private init() {
        catalogNamesProvider = { Self.defaultPresentationImageNames }
        decodeHandler = { await Self.decodeImage(named: $0) }
        configureImageBudget()
    }

    private init(
        catalogNamesProvider: @escaping () -> [String],
        decodeHandler: @escaping @Sendable (String) async -> PreparedArtwork
    ) {
        self.catalogNamesProvider = catalogNamesProvider
        self.decodeHandler = decodeHandler
        configureImageBudget()
    }

    private func configureImageBudget() {
        let physicalMemory = Int(ProcessInfo.processInfo.physicalMemory)
        images.totalCostLimit = Self.totalCostLimit(forPhysicalMemory: physicalMemory)
    }

    nonisolated static func totalCostLimit(forPhysicalMemory physicalMemory: Int) -> Int {
        let adaptiveBudget = physicalMemory / 24
        // 6 GB typical target: 320 MiB artwork / 550 MiB process. Leave room
        // below the artwork target for the small strong pin set and temporary
        // decoder surfaces that NSCache does not cost-account. Do not lower
        // floor to 96 or cap to 160 to re-target 4 GB without product approval.
        return min(max(adaptiveBudget, 160 * 1024 * 1024), 260 * 1024 * 1024)
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

    public var progress: Double {
        min(Double(completedCount) / Double(max(totalCount, 1)), 1)
    }

    public func image(named name: String) -> UIImage? {
        pinnedImages[name] ?? images.object(forKey: name as NSString)
    }

    /// Decodes artwork into the cache without retaining a strong pin. Use this
    /// for previews whose view owns the immediate presentation lifetime.
    public func prepare(names: [String]) async {
        let unique = Array(Set(names)).sorted()
        guard !unique.isEmpty else { return }
        await decode(unique, maximumConcurrency: 2, countsTowardLaunch: false)
    }

    /// Decode and pin images that must survive NSCache pressure during a short
    /// preparation lifecycle (for example, opening-hand ability art for an
    /// imminent battle). The owner must call `releasePins(names:)` when that
    /// lifecycle ends.
    public func prepareAndPin(names: [String]) async {
        let unique = Array(Set(names)).sorted()
        guard !unique.isEmpty else { return }
        for name in unique {
            pinCountsByName[name, default: 0] += 1
            if let image = images.object(forKey: name as NSString) {
                pinnedImages[name] = image
            }
        }
        // Decoded results are pinned inside decode() while the pin count is
        // held; an owner that releases mid-decode must stay released.
        await decode(unique, maximumConcurrency: 2, countsTowardLaunch: false)
    }

    /// Releases strong references held for a completed or cancelled preparation.
    /// The decoded bitmap remains eligible in `NSCache` and can be reloaded if
    /// memory pressure evicts it.
    public func releasePins(names: [String]) {
        for name in Set(names) {
            guard let count = pinCountsByName[name] else { continue }
            if count > 1 {
                pinCountsByName[name] = count - 1
            } else {
                pinCountsByName.removeValue(forKey: name)
                pinnedImages.removeValue(forKey: name)
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
        launchWarmupNames = plan.priorityNames + plan.deferredNames
        totalCount = max(plan.priorityNames.count + plan.deferredNames.count, 1)
        completedCount = 0
        isDeferredWarmupComplete = false
        for name in Set(plan.priorityNames) {
            pinCountsByName[name, default: 0] += 1
        }

        let task = Task(priority: .userInitiated) { @MainActor [weak self] in
            guard let self else { return }
            await decode(plan.priorityNames, maximumConcurrency: 2, countsTowardLaunch: true)
            isLaunchWarmupComplete = true
            reportMemorySnapshot(label: "priorityWarmup")
        }
        priorityWarmupTask = task
        await task.value

        deferredWarmupTask = Task(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }
            await decode(plan.deferredNames, maximumConcurrency: 2, countsTowardLaunch: true)
            isDeferredWarmupComplete = true
            completedCount = totalCount
            reportMemorySnapshot(label: "deferredWarmup")
        }
    }

    /// Test seam for awaiting the intentionally detached deferred warmup task.
    /// Production launch does not block on the full catalog.
    func waitForDeferredWarmup() async {
        guard let deferredWarmupTask else { return }
        await deferredWarmupTask.value
    }

    private func decode(
        _ imageNames: [String],
        maximumConcurrency: Int,
        countsTowardLaunch: Bool
    ) async {
        let namesToDecode = imageNames.filter { name in
            pinnedImages[name] == nil && images.object(forKey: name as NSString) == nil
        }
        if countsTowardLaunch {
            completedCount += imageNames.count - namesToDecode.count
        }

        let decode = decodeHandler
        await withTaskGroup(of: PreparedArtwork.self) { group in
            var iterator = namesToDecode.makeIterator()

            for _ in 0 ..< maximumConcurrency {
                guard let name = iterator.next() else { break }
                group.addTask { await decode(name) }
            }

            while let prepared = await group.next() {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return
                }
                if let image = prepared.image {
                    let decodedCost = Self.decodedCost(of: image)
                    images.setObject(
                        image,
                        forKey: prepared.name as NSString,
                        cost: decodedCost
                    )
                    decodedCostsByName[prepared.name] = decodedCost
                    if pinCountsByName[prepared.name] != nil {
                        pinnedImages[prepared.name] = image
                    }
                }
                if countsTowardLaunch {
                    completedCount += 1
                }

                if let name = iterator.next() {
                    group.addTask { await decode(name) }
                }
                await Task.yield()
            }
        }
    }

    func launchWarmupSnapshot() -> PreparedArtworkCacheSnapshot {
        var residentCount = 0
        var residentByteCount = 0
        var pinnedCount = 0
        var pinnedByteCount = 0

        for name in launchWarmupNames {
            let cost = decodedCostsByName[name] ?? 0
            if pinnedImages[name] != nil {
                residentCount += 1
                residentByteCount += cost
                pinnedCount += 1
                pinnedByteCount += cost
            } else if images.object(forKey: name as NSString) != nil {
                residentCount += 1
                residentByteCount += cost
            }
        }

        return PreparedArtworkCacheSnapshot(
            requestedCount: launchWarmupNames.count,
            residentCount: residentCount,
            residentByteCount: residentByteCount,
            pinnedCount: pinnedCount,
            pinnedByteCount: pinnedByteCount
        )
    }

    public func reportMemorySnapshot(label: String) {
        let snapshot = launchWarmupSnapshot()
        let processFootprintBytes = Self.processPhysicalFootprintByteCount()
        let artworkStatus = snapshot.residentByteCount
            <= PreparedArtworkMemoryBudget.residentArtworkByteCount ? "within" : "over"
        let processStatus = processFootprintBytes == 0
            || processFootprintBytes <= PreparedArtworkMemoryBudget.steadyStateProcessByteCount ? "within" : "over"
        let message = """
        \(label) requested=\(snapshot.requestedCount) resident=\(snapshot.residentCount) \
        nonresident=\(snapshot.nonresidentCount) residentBytes=\(snapshot.residentByteCount) \
        artworkBudgetBytes=\(PreparedArtworkMemoryBudget.residentArtworkByteCount) artworkStatus=\(artworkStatus) \
        pinned=\(snapshot.pinnedCount) pinnedBytes=\(snapshot.pinnedByteCount) \
        processFootprintBytes=\(processFootprintBytes) \
        processBudgetBytes=\(PreparedArtworkMemoryBudget.steadyStateProcessByteCount) processStatus=\(processStatus)
        """
        if artworkStatus == "over" || processStatus == "over" {
            logger.notice("\(message, privacy: .public)")
        } else {
            logger.info("\(message, privacy: .public)")
        }
    }

    private static func processPhysicalFootprintByteCount() -> Int {
        var information = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &information) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    rebound,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(information.phys_footprint)
    }

    nonisolated static func decodeImage(named name: String) async -> PreparedArtwork {
        guard !Task.isCancelled else {
            return PreparedArtwork(name: name, image: nil)
        }
        guard let source = UIImage(named: name) else {
            return PreparedArtwork(name: name, image: nil)
        }
        guard !Task.isCancelled else {
            return PreparedArtwork(name: name, image: nil)
        }
        let prepared = await source.byPreparingForDisplay()
        return PreparedArtwork(name: name, image: prepared)
    }

    nonisolated static func decodedCost(of image: UIImage) -> Int {
        guard let image = image.cgImage else { return 0 }
        return image.bytesPerRow * image.height
    }

    static var defaultPresentationImageNames: [String] {
        var names = Set<String>()

        for reference in ArtCatalog.combatantArtByID.values {
            names.insert(reference.imageName)
            if let thumbnailImageName = reference.thumbnailImageName {
                names.insert(thumbnailImageName)
            }
        }
        for reference in ArtCatalog.abilityArtByID.values {
            names.insert(reference.imageName)
            if let thumbnailImageName = reference.thumbnailImageName {
                names.insert(thumbnailImageName)
            }
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
            if let thumbnailImageName = reference.thumbnailImageName {
                names.insert(thumbnailImageName)
            }
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
        for reference in ArtCatalog.talentArtByID.values {
            names.insert(reference.imageName)
            if let thumbnailImageName = reference.thumbnailImageName {
                names.insert(thumbnailImageName)
            }
        }

        return names.sorted()
    }
}
