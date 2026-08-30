import Darwin
import Observation
import os
import SwiftUI
import TrinketContent
import UIKit

struct LaunchArtworkWarmupPlan: Equatable {
    let priorityNames: [String]
    let deferredNames: [String]

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

enum PreparedArtworkMemoryBudget {
    static let residentArtworkByteCount = 320 * 1024 * 1024
    static let steadyStateProcessByteCount = 550 * 1024 * 1024
}

@MainActor
@Observable
public final class PreparedArtworkCache {
    public static let shared = PreparedArtworkCache()

    public private(set) var completedCount = 0
    public private(set) var totalCount = 1
    public private(set) var isLaunchWarmupComplete = false

    public private(set) var isDeferredWarmupComplete = false

    @ObservationIgnored private let images = NSCache<NSString, UIImage>()
    @ObservationIgnored private var pinnedImages: [String: UIImage] = [:]
    @ObservationIgnored private var pinCountsByName: [String: Int] = [:]
    @ObservationIgnored private var priorityWarmupTask: Task<Void, Never>?
    @ObservationIgnored private var deferredWarmupTask: Task<Void, Never>?
    @ObservationIgnored private var decodedCostsByName: [String: Int] = [:]
    @ObservationIgnored private var launchWarmupNames: [String] = []
    @ObservationIgnored private var inFlightNames: Set<String> = []
    @ObservationIgnored private var decodeWaitersByName: [String: [CheckedContinuation<Bool, Never>]] = [:]
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
        let limit = Self.totalCostLimit(forPhysicalMemory: physicalMemory)
        assert(
            limit >= 160 * 1024 * 1024,
            "PreparedArtworkCache totalCostLimit must not drop below 160 MiB hitch budget"
        )
        images.totalCostLimit = limit
    }

    nonisolated static func totalCostLimit(forPhysicalMemory physicalMemory: Int) -> Int {
        let adaptiveBudget = physicalMemory / 24
        return min(max(adaptiveBudget, 160 * 1024 * 1024), 260 * 1024 * 1024)
    }

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

    public func prepare(names: [String]) async {
        let unique = Array(Set(names)).sorted()
        guard !unique.isEmpty else { return }
        await decode(unique, maximumConcurrency: 2, countsTowardLaunch: false)
    }

    public func prepareAndPin(names: [String]) async {
        let unique = Array(Set(names)).sorted()
        guard !unique.isEmpty else { return }
        for name in unique {
            pinCountsByName[name, default: 0] += 1
            if let image = images.object(forKey: name as NSString) {
                pinnedImages[name] = image
            }
        }
        await decode(unique, maximumConcurrency: 2, countsTowardLaunch: false)
    }

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
            pinnedImages[name] == nil
                && images.object(forKey: name as NSString) == nil
        }
        if countsTowardLaunch {
            completedCount += imageNames.count - namesToDecode.count
        }
        guard !namesToDecode.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            var iterator = namesToDecode.makeIterator()

            for _ in 0 ..< maximumConcurrency {
                guard let name = iterator.next() else { break }
                group.addTask {
                    await self.prepareArtwork(named: name)
                }
            }

            while await group.next() != nil {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return
                }
                if countsTowardLaunch {
                    completedCount += 1
                }

                if let name = iterator.next() {
                    group.addTask {
                        await self.prepareArtwork(named: name)
                    }
                }
                await Task.yield()
            }
        }
    }

    private func prepareArtwork(named name: String) async {
        guard pinnedImages[name] == nil,
              images.object(forKey: name as NSString) == nil
        else {
            return
        }
        if inFlightNames.contains(name) {
            let shouldRetry = await withCheckedContinuation { continuation in
                decodeWaitersByName[name, default: []].append(continuation)
            }
            if shouldRetry, !Task.isCancelled {
                await prepareArtwork(named: name)
            }
            return
        }

        inFlightNames.insert(name)
        let prepared = await decodeHandler(name)
        let wasCancelled = Task.isCancelled
        if let image = prepared.image, !wasCancelled {
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
        } else {
            assert(
                pinnedImages[prepared.name] == nil,
                "Failed decode must not have a pinned bitmap for \(prepared.name)"
            )
        }
        inFlightNames.remove(name)
        let waiters = decodeWaitersByName.removeValue(forKey: name) ?? []
        for waiter in waiters {
            waiter.resume(returning: wasCancelled)
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
        ArtCatalog.allImageNames
    }
}
