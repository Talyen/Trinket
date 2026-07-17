import SwiftUI
import TrinketDesignSystem

/// Incremental event-delta bridge to always-mounted UIKit hosts. Inserts and
/// expirations touch only the affected target instead of rebuilding battle snapshots.
@MainActor
enum CombatFeedbackChipBridge {
    private static var hosts: [ObjectIdentifier: WeakHost] = [:]
    private static var itemsByTarget: [String: [Int: CombatFeedbackItem]] = [:]
    private static var pendingAvailabilityTask: Task<Void, Never>?

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
        }

        // Refresh applies warm hits immediately and paces cold compose + re-flush.
        refreshHosts(for: affectedTargets)
        scheduleAvailabilityRefreshes()
    }

    private static func scheduleAvailabilityRefreshes() {
        pendingAvailabilityTask?.cancel()
        let now = Date()
        let dates = Set(itemsByTarget.values.flatMap(\.values).compactMap { item in
            item.availableAt > now ? item.availableAt : nil
        }).sorted()
        guard !dates.isEmpty else {
            pendingAvailabilityTask = nil
            return
        }
        pendingAvailabilityTask = Task { @MainActor in
            for date in dates {
                let delay = date.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                let targets = Set(itemsByTarget.compactMap { targetID, items in
                    items.values.contains { $0.availableAt <= date && date < $0.expiresAt }
                        ? targetID
                        : nil
                })
                refreshHosts(for: targets)
            }
            pendingAvailabilityTask = nil
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
        // Never sync-compose on the flush frame — paced prepare + re-flush keeps
        // ChipHostApply off cold FeedbackRasterBuild stalls.
        if !misses.isEmpty {
            CombatFeedbackRasterPool.shared.prepareCanvasItems(
                misses,
                dynamicTypeSize: entry.dynamicTypeSize,
                layoutDirection: entry.layoutDirection,
                displayScale: entry.displayScale,
                useFrameBudget: true
            ) {
                refreshHosts(for: [entry.combatantID])
            }
        }
        view.apply(chips: chips)
    }
}
