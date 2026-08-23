import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

/// Incremental event-delta bridge to always-mounted UIKit hosts. Inserts and
/// expirations touch only the affected target instead of rebuilding battle snapshots.
@MainActor
enum CombatFeedbackChipBridge {
    private static var hosts: [ObjectIdentifier: WeakHost] = [:]
    private static var itemsByTarget: [String: [Int: CombatFeedbackItem]] = [:]
    private static var availabilityTimer: Timer?
    private static let availabilityTimerTarget = AvailabilityTimerTarget()
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
        displayScale: CGFloat
    ) {
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
        case let .update(items):
            for item in items where itemsByTarget[item.targetID]?[item.id] != nil {
                itemsByTarget[item.targetID]?[item.id] = item
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
            nextAvailabilityDate = nil
            nextAvailabilityTargetID = nil
        }

        // Refresh applies visible chips immediately (compose on miss).
        refreshHosts(for: affectedTargets)
        updateAvailabilityWakeTime(considering: affectedTargets)
    }

    /// Publish frames only update a resident timer's fire date. No idle polling or
    /// per-publish Task allocation is required. Only the touched targets and the
    /// previously scheduled wake are considered, so cost is O(changed) not O(total).
    private static func updateAvailabilityWakeTime(considering affectedTargets: Set<String>) {
        let now = Date()
        var earliest: Date?
        var earliestTargetID: String?
        // The previously scheduled wake stays valid when its source target is untouched.
        if let previous = nextAvailabilityDate,
           let targetID = nextAvailabilityTargetID,
           !affectedTargets.contains(targetID) {
            earliest = previous
            earliestTargetID = targetID
        }
        for targetID in affectedTargets {
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
        scheduleAvailabilityTimer()
    }

    private static func scheduleAvailabilityTimer() {
        if availabilityTimer == nil {
            let timer = Timer(
                timeInterval: 86400,
                target: availabilityTimerTarget,
                selector: #selector(AvailabilityTimerTarget.fire),
                userInfo: nil,
                repeats: false
            )
            timer.fireDate = .distantFuture
            RunLoop.main.add(timer, forMode: .common)
            availabilityTimer = timer
        }
        availabilityTimer?.fireDate = nextAvailabilityDate ?? .distantFuture
    }

    fileprivate static func availabilityTimerDidFire() {
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
        let chipsToDraw = CombatFeedbackOverlayPolicy.orderedChips(from: visible.sorted {
            if $0.availableAt == $1.availableAt {
                return $0.id < $1.id
            }
            return $0.availableAt < $1.availableAt
        })
        var chips: [(item: CombatFeedbackItem, raster: CombatFeedbackRaster?)] = []
        var misses: [CombatFeedbackItem] = []
        for item in chipsToDraw {
            if let raster = CombatFeedbackRasterPool.shared.cachedRaster(
                for: item,
                layoutDirection: entry.layoutDirection,
                displayScale: entry.displayScale
            ) {
                chips.append((item: item, raster: raster))
            } else {
                misses.append(item)
            }
        }
        // Compose misses on this flush. Warm glyph-atlas blits stay sub-ms; pacing
        // them behind a park wake was making feedback text late or miss entirely.
        if !misses.isEmpty {
            for item in misses {
                if let raster = CombatFeedbackRasterPool.shared.prepare(
                    for: item,
                    layoutDirection: entry.layoutDirection,
                    displayScale: entry.displayScale
                ) {
                    chips.append((item: item, raster: raster))
                }
            }
        }
        view.apply(chips: chips)
    }
}

@MainActor
private final class AvailabilityTimerTarget: NSObject {
    @objc func fire() {
        CombatFeedbackChipBridge.availabilityTimerDidFire()
    }
}
