import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

@MainActor
final class CombatFeedbackChipBridge {
    private var hosts: [ObjectIdentifier: WeakHost] = [:]
    private var evictedIDs: Set<Int> = []
    private var suppressedTargets: Set<String> = []
    private let onEvict: ((Set<Int>) -> Void)?
    private var itemsByTarget: [String: [Int: CombatFeedbackItem]] = [:]
    private var motionTracks: [Int: CombatFeedbackMotionTrack] = [:]
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

    private struct ResolutionKey: Hashable {
        let combatantID: String
        let layoutDirection: LayoutDirection
        let displayScale: CGFloat
    }

    private typealias ResolvedChip = (item: CombatFeedbackItem, raster: CombatFeedbackRaster?)

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
            refreshHosts(for: [combatantID], hostKeys: [key], at: .now)
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

        let now = Date.now
        var affectedTargets = suppressedTargets
        suppressedTargets.removeAll(keepingCapacity: true)
        switch update {
        case let .remove(ids):
            evictedIDs.subtract(ids)
            for id in ids {
                motionTracks.removeValue(forKey: id)
            }
            for targetID in Array(itemsByTarget.keys) {
                for id in ids where itemsByTarget[targetID]?.removeValue(forKey: id) != nil {
                    affectedTargets.insert(targetID)
                }
                if itemsByTarget[targetID]?.isEmpty == true {
                    itemsByTarget.removeValue(forKey: targetID)
                }
            }
        case let .replace(items):
            let liveIDs = Set(items.map(\.id))
            evictedIDs.formIntersection(liveIDs)
            for id in Array(motionTracks.keys) where !liveIDs.contains(id) {
                motionTracks.removeValue(forKey: id)
            }
            for id in liveIDs where motionTracks[id] == nil {
                motionTracks[id] = CombatFeedbackMotionTrack()
            }
            var replacement: [String: [Int: CombatFeedbackItem]] = [:]
            for item in items {
                replacement[item.targetID, default: [:]][item.id] = item
            }
            affectedTargets.formUnion(Set(itemsByTarget.keys).union(replacement.keys).filter {
                itemsByTarget[$0] != replacement[$0]
            })
            itemsByTarget = replacement
        case .reset:
            evictedIDs.removeAll()
            affectedTargets = Set(itemsByTarget.keys)
            itemsByTarget.removeAll(keepingCapacity: true)
            motionTracks.removeAll(keepingCapacity: true)
            nextAvailabilityDate = nil
            nextAvailabilityTargetID = nil
        }

        // An identical publication can arrive before a due timer gets its main-actor turn.
        if let deadline = nextAvailabilityDate, deadline <= now {
            affectedTargets.formUnion(availableTargets(at: now))
        }
        refreshHosts(for: affectedTargets, at: now)
        updateAvailabilityWakeTime(considering: affectedTargets, at: now)
    }

    private func updateAvailabilityWakeTime(considering affectedTargets: Set<String>, at now: Date) {
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
        refreshHosts(for: availableTargets(at: now), at: now)
        updateAvailabilityWakeTime(considering: Set(itemsByTarget.keys), at: now)
    }

    private func availableTargets(at now: Date) -> Set<String> {
        Set(itemsByTarget.compactMap { targetID, items in
            items.values.contains { $0.availableAt <= now && now < $0.expiresAt }
                ? targetID
                : nil
        })
    }

    private func refreshHosts(
        for targetIDs: Set<String>,
        hostKeys: [ObjectIdentifier]? = nil,
        at now: Date,
    ) {
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
        var resolved: [ResolutionKey: [ResolvedChip]] = [:]
        for key in hostKeys ?? Array(hosts.keys) {
            guard let entry = hosts[key], targetIDs.contains(entry.combatantID) else { continue }
            guard let view = entry.view else {
                hosts.removeValue(forKey: key)
                continue
            }
            let resolutionKey = ResolutionKey(
                combatantID: entry.combatantID,
                layoutDirection: entry.layoutDirection,
                displayScale: entry.displayScale,
            )
            let chips: [ResolvedChip]
            if let cached = resolved[resolutionKey] {
                chips = cached
            } else {
                chips = resolveChips(for: entry, at: now)
                resolved[resolutionKey] = chips
            }
            // Applying another fragment can synchronously evict chips from this lane.
            view.apply(chips: chips.filter { !evictedIDs.contains($0.item.id) }, motionTracks: motionTracks)
        }
    }

    private func resolveChips(
        for entry: WeakHost,
        at now: Date,
    ) -> [ResolvedChip] {
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
        return chips
    }

    private func suppress(_ ids: Set<Int>) {
        evictedIDs.formUnion(ids)
        suppressedTargets.formUnion(itemsByTarget.compactMap { targetID, items in
            ids.contains(where: { items[$0] != nil }) ? targetID : nil
        })
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
