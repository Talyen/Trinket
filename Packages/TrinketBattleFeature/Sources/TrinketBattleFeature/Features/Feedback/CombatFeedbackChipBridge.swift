import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

@MainActor
enum CombatFeedbackChipBridge {
    private static var hosts: [ObjectIdentifier: WeakHost] = [:]
    private static var evictedIDs: Set<Int> = []
    private static var onEvict: ((Set<Int>) -> Void)?
    private static var itemsByTarget: [String: [Int: CombatFeedbackItem]] = [:]
    private static let availabilityTimer = FeedbackDeadlineTimer {
        availabilityTimerDidFire()
    }

    private static var nextAvailabilityDate: Date?
    private static var nextAvailabilityTargetID: String?

    private struct WeakHost {
        weak var view: CombatFeedbackRasterUIView?
        let combatantID: String
        let layoutDirection: LayoutDirection
        let displayScale: CGFloat
    }

    static func register(
        _ view: CombatFeedbackRasterUIView,
        combatantID: String,
        layoutDirection: LayoutDirection,
        displayScale: CGFloat,
    ) {
        view.onEvict = suppress
        let key = ObjectIdentifier(view)
        let previous = hosts[key]
        let metadataChanged = previous == nil
            || previous?.view !== view
            || previous?.combatantID != combatantID
            || previous?.layoutDirection != layoutDirection
            || previous?.displayScale != displayScale
        hosts[key] = WeakHost(
            view: view,
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
        )
        if metadataChanged {
            refresh(hostKey: key)
        }
    }

    static func unregister(_ view: CombatFeedbackRasterUIView) {
        hosts.removeValue(forKey: ObjectIdentifier(view))
    }

    static func publish(_ update: CombatFeedbackUpdate) {
        publish(update, onEvict: nil)
    }

    static func publish(_ update: CombatFeedbackUpdate, onEvict: ((Set<Int>) -> Void)?) {
        self.onEvict = onEvict
        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.chipPublish,
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.chipPublish,
                intervalState,
            )
        }

        var affectedTargets = Set<String>()
        switch update {
        case let .remove(ids):
            evictedIDs.subtract(ids)
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
            evictedIDs.formIntersection(Set(items.map(\.id)))
            affectedTargets = Set(itemsByTarget.keys).union(items.map(\.targetID))
            itemsByTarget = Dictionary(grouping: items, by: \.targetID).mapValues { targetItems in
                Dictionary(uniqueKeysWithValues: targetItems.map { ($0.id, $0) })
            }
        case .reset:
            evictedIDs.removeAll()
            affectedTargets = Set(itemsByTarget.keys)
            itemsByTarget.removeAll(keepingCapacity: true)
            nextAvailabilityDate = nil
            nextAvailabilityTargetID = nil
        }

        refreshHosts(for: affectedTargets)
        updateAvailabilityWakeTime(considering: affectedTargets)
    }

    private static func updateAvailabilityWakeTime(considering affectedTargets: Set<String>) {
        let now = Date()
        var earliest: Date?
        var earliestTargetID: String?
        if let previous = nextAvailabilityDate,
           let targetID = nextAvailabilityTargetID,
           !affectedTargets.contains(targetID),
           previous > now {
            earliest = previous
            earliestTargetID = targetID
        }
        let searchTargets = earliestTargetID == nil ? Set(itemsByTarget.keys) : affectedTargets
        for targetID in searchTargets {
            guard let items = itemsByTarget[targetID] else { continue }
            for item in items.values where item.availableAt > now {
                if item.availableAt < (earliest ?? .distantFuture) {
                    earliest = item.availableAt
                    earliestTargetID = targetID
                }
            }
        }
        nextAvailabilityDate = earliest
        nextAvailabilityTargetID = earliestTargetID
        availabilityTimer.schedule(at: nextAvailabilityDate)
    }

    private static func availabilityTimerDidFire() {
        let now = Date.now
        let targets = Set(itemsByTarget.compactMap { targetID, items in
            items.values.contains { $0.availableAt <= now && now < $0.expiresAt }
                ? targetID
                : nil
        })
        refreshHosts(for: targets)
        updateAvailabilityWakeTime(considering: Set(itemsByTarget.keys))
    }

    private static func refreshHosts(for targetIDs: Set<String>) {
        guard !targetIDs.isEmpty else { return }
        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.chipFlush,
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.chipFlush,
                intervalState,
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
            !evictedIDs.contains(item.id) && now >= item.availableAt && (item.pausedAt ?? now) < item.expiresAt
        }
        let chipsToDraw = CombatFeedbackOrdering.orderedChips(from: visible.sorted {
            if $0.availableAt == $1.availableAt {
                return $0.id < $1.id
            }
            return $0.availableAt < $1.availableAt
        })
        var chips: [(item: CombatFeedbackItem, raster: CombatFeedbackRaster?)] = []
        for item in chipsToDraw {
            let raster = CombatFeedbackRasterPool.shared.cachedRaster(
                for: item,
                layoutDirection: entry.layoutDirection,
                displayScale: entry.displayScale,
            ) ?? CombatFeedbackRasterPool.shared.prepare(
                for: item,
                layoutDirection: entry.layoutDirection,
                displayScale: entry.displayScale,
            )
            chips.append((item: item, raster: raster))
        }
        view.apply(chips: chips)
    }

    private static func suppress(_ ids: Set<Int>) {
        evictedIDs.formUnion(ids)
        onEvict?(ids)
    }

    #if DEBUG
    static var debugNextAvailabilityDate: Date? {
        nextAvailabilityDate
    }

    static var debugNextAvailabilityTargetID: String? {
        nextAvailabilityTargetID
    }

    static func debugReset() {
        hosts.removeAll()
        evictedIDs.removeAll()
        onEvict = nil
        itemsByTarget.removeAll()
        nextAvailabilityDate = nil
        nextAvailabilityTargetID = nil
        availabilityTimer.cancel()
    }
    #endif
}
