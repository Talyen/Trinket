import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

@MainActor
final class CombatFeedbackChipBridge {
    private var hosts: [ObjectIdentifier: WeakHost] = [:]
    private var evictedIDs: Set<Int> = []
    private var suppressedTargets: Set<String> = []
    private let onEvict: ((Set<Int>) -> Void)?
    private var itemsByTarget: [String: [Int: CombatFeedbackItem]] = [:]
    private var targetsByItemID: [Int: String] = [:]
    private var motionTracks: [Int: CombatFeedbackMotionTrack] = [:]
    private var liveRasters: [ResolutionKey: [Int: LiveRaster]] = [:]
    private let rasterPool: CombatFeedbackRasterPool
    private lazy var availabilityTimer = FeedbackDeadlineTimer { [weak self] in
        self?.availabilityTimerDidFire()
    }

    init(rasterPool: CombatFeedbackRasterPool = .shared, onEvict: ((Set<Int>) -> Void)? = nil) {
        self.rasterPool = rasterPool
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

    private struct LiveRaster {
        let label: CombatFeedbackChipLabel
        let keyword: Keyword
        let visualRole: CombatFeedbackVisualRole
        let typography: CombatFeedbackTypographyTier
        let raster: CombatFeedbackRaster

        init(item: CombatFeedbackItem, raster: CombatFeedbackRaster) {
            label = item.label
            keyword = item.keyword
            visualRole = item.visualRole
            typography = item.feedbackClass.typographyTier
            self.raster = raster
        }

        func matches(_ item: CombatFeedbackItem) -> Bool {
            label == item.label && keyword == item.keyword
                && visualRole == item.visualRole && typography == item.feedbackClass.typographyTier
        }
    }

    private typealias ResolvedChip = (item: CombatFeedbackItem, raster: CombatFeedbackRaster?)

    func register(
        _ view: CombatFeedbackRasterUIView,
        combatantID: String,
        layoutDirection: LayoutDirection,
        displayScale: CGFloat,
    ) {
        let key = ObjectIdentifier(view)
        if let previous = hosts[key],
           previous.view === view,
           previous.combatantID == combatantID,
           previous.layoutDirection == layoutDirection,
           previous.displayScale == displayScale {
            return
        }
        view.onEvict = { [weak self] ids in self?.suppress(ids) }
        hosts[key] = WeakHost(
            view: view,
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
        )
        // Retain unmounted fragments until remount, but discard obsolete scale/direction contexts.
        let liveContexts = Set(hosts.values.lazy.map {
            ResolutionKey(combatantID: $0.combatantID, layoutDirection: $0.layoutDirection, displayScale: $0.displayScale)
        })
        liveRasters = liveRasters.filter { liveContexts.contains($0.key) }
        refreshHosts(for: [combatantID], hostKeys: [key], at: .now)
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
            removeItems(ids, affectedTargets: &affectedTargets)
        case let .patch(items, removing):
            patchItems(items, removing: removing, affectedTargets: &affectedTargets)
        case let .replace(items):
            let liveIDs = Set(items.lazy.map(\.id))
            let retiredIDs = Set(motionTracks.keys.lazy.filter { !liveIDs.contains($0) })
            releaseRasters(ids: retiredIDs)
            evictedIDs.formIntersection(liveIDs)
            for id in retiredIDs {
                motionTracks.removeValue(forKey: id)
            }
            for id in liveIDs where motionTracks[id] == nil {
                motionTracks[id] = CombatFeedbackMotionTrack()
            }
            var replacement: [String: [Int: CombatFeedbackItem]] = [:]
            targetsByItemID.removeAll(keepingCapacity: true)
            for item in items {
                replacement[item.targetID, default: [:]][item.id] = item
                targetsByItemID[item.id] = item.targetID
            }
            for target in itemsByTarget.keys where itemsByTarget[target] != replacement[target] {
                affectedTargets.insert(target)
            }
            for target in replacement.keys where itemsByTarget[target] == nil {
                affectedTargets.insert(target)
            }
            itemsByTarget = replacement
        case .reset:
            evictedIDs.removeAll()
            affectedTargets = Set(itemsByTarget.keys)
            itemsByTarget.removeAll(keepingCapacity: true)
            targetsByItemID.removeAll(keepingCapacity: true)
            motionTracks.removeAll(keepingCapacity: true)
            liveRasters.removeAll(keepingCapacity: true)
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

    private func patchItems(_ items: [CombatFeedbackItem], removing: Set<Int>, affectedTargets: inout Set<String>) {
        removeItems(removing, affectedTargets: &affectedTargets)
        for item in items where !removing.contains(item.id) {
            if let previousTarget = targetsByItemID[item.id], previousTarget != item.targetID {
                itemsByTarget[previousTarget]?.removeValue(forKey: item.id)
                if itemsByTarget[previousTarget]?.isEmpty == true {
                    itemsByTarget.removeValue(forKey: previousTarget)
                }
                affectedTargets.insert(previousTarget)
                releaseRasters(ids: [item.id])
            }
            guard itemsByTarget[item.targetID]?[item.id] != item else { continue }
            itemsByTarget[item.targetID, default: [:]][item.id] = item
            targetsByItemID[item.id] = item.targetID
            if motionTracks[item.id] == nil {
                motionTracks[item.id] = CombatFeedbackMotionTrack()
            }
            affectedTargets.insert(item.targetID)
        }
    }

    private func removeItems(_ ids: Set<Int>, affectedTargets: inout Set<String>) {
        releaseRasters(ids: ids)
        evictedIDs.subtract(ids)
        for id in ids {
            motionTracks.removeValue(forKey: id)
            guard let targetID = targetsByItemID.removeValue(forKey: id) else { continue }
            itemsByTarget[targetID]?.removeValue(forKey: id)
            affectedTargets.insert(targetID)
            if itemsByTarget[targetID]?.isEmpty == true {
                itemsByTarget.removeValue(forKey: targetID)
            }
        }
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
        Set(itemsByTarget.lazy.compactMap { targetID, items in
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
            if evictedIDs.isEmpty {
                view.apply(chips: chips, motionTracks: motionTracks)
            } else {
                view.apply(chips: chips.filter { !evictedIDs.contains($0.item.id) }, motionTracks: motionTracks)
            }
        }
    }

    private func resolveChips(
        for entry: WeakHost,
        at now: Date,
    ) -> [ResolvedChip] {
        let targetItems = itemsByTarget[entry.combatantID] ?? [:]
        let visible = targetItems.values.lazy.filter { item in
            !self.evictedIDs.contains(item.id) && now >= item.availableAt && (item.pausedAt ?? now) < item.expiresAt
        }
        let chipsToDraw = CombatFeedbackOrdering.orderedChips(from: visible.sorted {
            if $0.availableAt == $1.availableAt {
                return $0.id < $1.id
            }
            return $0.availableAt < $1.availableAt
        })
        var chips: [(item: CombatFeedbackItem, raster: CombatFeedbackRaster?)] = []
        let context = ResolutionKey(
            combatantID: entry.combatantID, layoutDirection: entry.layoutDirection, displayScale: entry.displayScale,
        )
        for item in chipsToDraw {
            let raster: CombatFeedbackRaster?
            // Timing, source IDs, and reservation changes cannot alter these pixels.
            // Compare semantic inputs before formatting an unchanged numeric label.
            if let retained = liveRasters[context]?[item.id], retained.matches(item) {
                raster = retained.raster
            } else {
                raster = rasterPool.prepare(for: item, layoutDirection: entry.layoutDirection, displayScale: entry.displayScale)
                liveRasters[context, default: [:]][item.id] = raster.map { LiveRaster(item: item, raster: $0) }
            }
            chips.append((item: item, raster: raster))
        }
        return chips
    }

    private func suppress(_ ids: Set<Int>) {
        releaseRasters(ids: ids)
        evictedIDs.formUnion(ids)
        // The reverse index answers target membership directly instead of
        // scanning every target's item dictionary.
        suppressedTargets.formUnion(ids.lazy.compactMap { self.targetsByItemID[$0] })
        onEvict?(ids)
    }

    private func releaseRasters(ids: Set<Int>) {
        guard !ids.isEmpty else { return }
        for context in Array(liveRasters.keys) {
            for id in ids {
                liveRasters[context]?.removeValue(forKey: id)
            }
            if liveRasters[context]?.isEmpty == true {
                liveRasters.removeValue(forKey: context)
            }
        }
    }

    func balancedSchedule(_ item: CombatFeedbackItem, at date: Date, previous: [CombatFeedbackItem]) -> CombatFeedbackItem {
        let host = hosts.values.first { $0.combatantID == item.targetID && $0.view != nil }
        let bounds = host?.view?.bounds ?? CGRect(x: 0, y: 0, width: 180, height: 250)
        let bottomInset = host?.view?.bottomInset ?? 0
        let direction = host?.layoutDirection ?? .leftToRight
        let displayScale = host?.displayScale ?? 3
        var reserved = item
        if case .amount = item.label {
            reserved.reservedDigitCount = item.label.displayString.count + 1
        }
        return BalancedFeedbackMotion.schedule(reserved, at: date, previous: previous, bounds: bounds, bottomInset: bottomInset) { item in
            self.rasterPool.prepare(for: item, layoutDirection: direction, displayScale: displayScale)
        }
    }

    var debugItemIDs: Set<Int> {
        Set(itemsByTarget.values.lazy.flatMap(\.keys)).subtracting(evictedIDs)
    }

    var debugNextAvailabilityDate: Date? {
        nextAvailabilityDate
    }

    var debugNextAvailabilityTargetID: String? {
        nextAvailabilityTargetID
    }
}
