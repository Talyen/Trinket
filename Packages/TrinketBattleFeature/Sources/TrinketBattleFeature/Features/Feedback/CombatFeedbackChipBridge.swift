import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

@MainActor
final class CombatFeedbackChipBridge {
    private var hosts: [ObjectIdentifier: WeakHost] = [:]
    private var evictedIDs: Set<Int> = []
    private let onEvict: ((Set<Int>) -> Void)?
    private var itemsByTarget: [String: [Int: CombatFeedbackItem]] = [:]
    private lazy var availabilityTimer = FeedbackDeadlineTimer { [weak self] in
        self?.availabilityTimerDidFire()
    }

    init(onEvict: ((Set<Int>) -> Void)? = nil) {
        self.onEvict = onEvict
    }

    private var nextAvailabilityDate: Date?
    private var nextAvailabilityTargetID: String?

    private struct WeakHost {
        weak var view: CombatFeedbackRasterUIView?
        let combatantID: String
        let layoutDirection: LayoutDirection
        let displayScale: CGFloat
    }

    func register(
        _ view: CombatFeedbackRasterUIView,
        combatantID: String,
        layoutDirection: LayoutDirection,
        displayScale: CGFloat,
    ) {
        view.onEvict = { [weak self] ids in self?.suppress(ids) }
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

    func unregister(_ view: CombatFeedbackRasterUIView) {
        view.stopMotion()
        view.onEvict = nil
        hosts.removeValue(forKey: ObjectIdentifier(view))
    }

    func publish(_ update: CombatFeedbackUpdate) {
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

    private func updateAvailabilityWakeTime(considering affectedTargets: Set<String>) {
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

    private func availabilityTimerDidFire() {
        let now = Date.now
        let targets = Set(itemsByTarget.compactMap { targetID, items in
            items.values.contains { $0.availableAt <= now && now < $0.expiresAt }
                ? targetID
                : nil
        })
        refreshHosts(for: targets)
        updateAvailabilityWakeTime(considering: Set(itemsByTarget.keys))
    }

    private func refreshHosts(for targetIDs: Set<String>) {
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

    private func refresh(hostKey: ObjectIdentifier) {
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

    private func suppress(_ ids: Set<Int>) {
        evictedIDs.formUnion(ids)
        onEvict?(ids)
    }

    #if DEBUG
    var debugItemIDs: Set<Int> {
        Set(itemsByTarget.values.flatMap(\.keys)).subtracting(evictedIDs)
    }

    var debugNextAvailabilityDate: Date? {
        nextAvailabilityDate
    }

    var debugNextAvailabilityTargetID: String? {
        nextAvailabilityTargetID
    }
    #endif
}
