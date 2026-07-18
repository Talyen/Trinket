import SwiftUI
import TrinketDesignSystem

/// Incremental event-delta bridge to always-mounted UIKit hosts. Inserts and
/// expirations touch only the affected target instead of rebuilding battle snapshots.
@MainActor
enum CombatFeedbackChipBridge {
    private static var hosts: [ObjectIdentifier: WeakHost] = [:]
    private static var itemsByTarget: [String: [Int: CombatFeedbackItem]] = [:]
    private static var pendingAvailabilityTask: Task<Void, Never>?
    /// Future `availableAt` wake times for the long-lived availability loop.
    private static var pendingAvailabilityDates: [Date] = []

    private struct WeakHost {
        weak var view: CombatFeedbackRasterUIView?
        let combatantID: String
        let dynamicTypeSize: DynamicTypeSize
        let layoutDirection: LayoutDirection
        let displayScale: CGFloat
    }

    static func register(
        _ view: CombatFeedbackRasterUIView,
        combatantID: String,
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection,
        displayScale: CGFloat
    ) {
        let key = ObjectIdentifier(view)
        let previous = hosts[key]
        let metadataChanged = previous == nil
            || previous?.view !== view
            || previous?.combatantID != combatantID
            || previous?.dynamicTypeSize != dynamicTypeSize
            || previous?.layoutDirection != layoutDirection
            || previous?.displayScale != displayScale
        hosts[key] = WeakHost(
            view: view,
            combatantID: combatantID,
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            displayScale: displayScale
        )
        if metadataChanged {
            refresh(hostKey: key)
        }
    }

    static func unregister(_ view: CombatFeedbackRasterUIView) {
        hosts.removeValue(forKey: ObjectIdentifier(view))
    }

    static func publish(_ update: CombatFeedbackUpdate) {
        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.chipPublish
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.chipPublish,
                intervalState
            )
        }

        var affectedTargets = Set<String>()
        switch update {
        case let .insert(items):
            for item in items {
                itemsByTarget[item.targetID, default: [:]][item.id] = item
                affectedTargets.insert(item.targetID)
            }
        case let .remove(ids):
            for targetID in Array(itemsByTarget.keys) {
                let removed = ids.filter { itemsByTarget[targetID]?.removeValue(forKey: $0) != nil }
                if !removed.isEmpty {
                    affectedTargets.insert(targetID)
                }
                if itemsByTarget[targetID]?.isEmpty == true {
                    itemsByTarget.removeValue(forKey: targetID)
                }
            }
        case let .replace(items):
            affectedTargets = Set(itemsByTarget.keys).union(items.map(\.targetID))
            itemsByTarget = Dictionary(grouping: items, by: \.targetID).mapValues { targetItems in
                Dictionary(uniqueKeysWithValues: targetItems.map { ($0.id, $0) })
            }
        case .reset:
            affectedTargets = Set(itemsByTarget.keys)
            itemsByTarget.removeAll(keepingCapacity: true)
            pendingAvailabilityDates.removeAll(keepingCapacity: true)
        }

        // Refresh applies visible chips immediately (compose on miss).
        refreshHosts(for: affectedTargets)
        noteAvailabilityWakeTimes()
    }

    /// Publish frames only record future `availableAt` dates. A single long-lived
    /// loop sleeps until those dates — no Task cancel/realloc on every insert.
    private static func noteAvailabilityWakeTimes() {
        let now = Date()
        let dates = Set(itemsByTarget.values.flatMap(\.values).compactMap { item in
            item.availableAt > now ? item.availableAt : nil
        }).sorted()
        pendingAvailabilityDates = dates
        ensureAvailabilityLoopRunning()
    }

    private static func ensureAvailabilityLoopRunning() {
        guard pendingAvailabilityTask == nil else { return }
        pendingAvailabilityTask = Task { @MainActor in
            while !Task.isCancelled {
                guard let fireAt = pendingAvailabilityDates.first else {
                    // Must stay interruptible: a 1s park made staggered chips miss
                    // their lifetime after publish bumped new availableAt dates.
                    try? await Task.sleep(for: .milliseconds(16))
                    continue
                }
                let delay = fireAt.timeIntervalSinceNow
                if delay > 0.016 {
                    // Chunk long waits so an earlier availableAt published mid-sleep
                    // is observed within one display frame.
                    try? await Task.sleep(for: .milliseconds(16))
                    continue
                }
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                // Cleared / reset while sleeping — do not refresh from a stale wake.
                guard let currentFirst = pendingAvailabilityDates.first else { continue }
                if currentFirst > fireAt {
                    continue
                }
                pendingAvailabilityDates.removeAll { $0 <= fireAt }
                let targets = Set(itemsByTarget.compactMap { targetID, items in
                    items.values.contains { $0.availableAt <= fireAt && fireAt < $0.expiresAt }
                        ? targetID
                        : nil
                })
                refreshHosts(for: targets)
            }
        }
    }

    private static func refreshHosts(for targetIDs: Set<String>) {
        guard !targetIDs.isEmpty else { return }
        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.chipFlush
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.chipFlush,
                intervalState
            )
        }
        for key in Array(hosts.keys) where hosts[key].map({ targetIDs.contains($0.combatantID) }) == true {
            refresh(hostKey: key)
        }
    }

    private static func refresh(hostKey: ObjectIdentifier) {
        guard let entry = hosts[hostKey] else { return }
        guard let view = entry.view else {
            hosts.removeValue(forKey: hostKey)
            return
        }
        let now = Date()
        let targetItems = itemsByTarget[entry.combatantID] ?? [:]
        let visible = targetItems.values.filter { item in
            now >= item.availableAt && now < item.expiresAt
        }
        let groups = CombatFeedbackOverlayPolicy.visibleActionGroups(from: visible.sorted {
            if $0.availableAt == $1.availableAt {
                return $0.id < $1.id
            }
            return $0.availableAt < $1.availableAt
        })
        let canvasItems = CombatFeedbackOverlayPolicy.canvasItems(from: groups)
        var chips: [(canvasItem: CombatFeedbackCanvasItem, raster: CombatFeedbackRaster?)] = []
        var misses: [CombatFeedbackCanvasItem] = []
        for canvasItem in canvasItems {
            if let raster = CombatFeedbackRasterPool.shared.cachedRaster(
                for: canvasItem,
                dynamicTypeSize: entry.dynamicTypeSize,
                layoutDirection: entry.layoutDirection,
                displayScale: entry.displayScale
            ) {
                chips.append((canvasItem: canvasItem, raster: raster))
            } else {
                misses.append(canvasItem)
            }
        }
        // Compose misses on this flush. Warm glyph-atlas blits stay sub-ms; pacing
        // them behind a park wake was making feedback text late or miss entirely.
        if !misses.isEmpty {
            for canvasItem in misses {
                if let raster = CombatFeedbackRasterPool.shared.prepare(
                    for: canvasItem,
                    dynamicTypeSize: entry.dynamicTypeSize,
                    layoutDirection: entry.layoutDirection,
                    displayScale: entry.displayScale
                ) {
                    chips.append((canvasItem: canvasItem, raster: raster))
                }
            }
        }
        view.apply(chips: chips)
    }
}
