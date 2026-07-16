import SwiftUI
import TrinketDesignSystem

/// Delivers chip updates to always-mounted UIKit hosts without requiring those
/// hosts to observe `feedbackEpoch` — the publish frame stays off SwiftUI chrome.
@MainActor
enum CombatFeedbackChipBridge {
    private static var hosts: [ObjectIdentifier: WeakHost] = [:]
    private static var latestItems: [CombatFeedbackItem] = []
    private static var pendingStaggerTask: Task<Void, Never>?

    private struct WeakHost {
        weak var view: CombatFeedbackRasterUIView?
        let combatantID: String
        let dynamicTypeSize: DynamicTypeSize
        let displayScale: CGFloat
    }

    /// Registers a host. Refreshes only on first attach or when presentation
    /// metadata changes — HP-driven `updateUIView` churn must not re-flush.
    static func register(
        _ view: CombatFeedbackRasterUIView,
        combatantID: String,
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) {
        let key = ObjectIdentifier(view)
        let previous = hosts[key]
        let metadataChanged = previous == nil
            || previous?.view !== view
            || previous?.combatantID != combatantID
            || previous?.dynamicTypeSize != dynamicTypeSize
            || previous?.displayScale != displayScale
        hosts[key] = WeakHost(
            view: view,
            combatantID: combatantID,
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        guard metadataChanged else { return }
        refresh(hostKey: key)
    }

    static func unregister(_ view: CombatFeedbackRasterUIView) {
        hosts.removeValue(forKey: ObjectIdentifier(view))
    }

    static func publish(items: [CombatFeedbackItem]) {
        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.chipPublish
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.chipPublish,
                intervalState
            )
        }
        latestItems = items
        prepareImminentRasters(for: items)
        flushRelevantHosts()
        scheduleStaggeredRefresh(for: items)
    }

    /// Composes the currently visible due chip for each host, then paces
    /// staggered future groups across display-link ticks.
    private static func prepareImminentRasters(for items: [CombatFeedbackItem]) {
        guard !items.isEmpty else { return }
        let now = Date()
        var preparedHostKeys = Set<String>()
        for entry in hosts.values {
            guard entry.view != nil else { continue }
            let hostKey = "\(entry.combatantID)|\(entry.dynamicTypeSize)|\(entry.displayScale)"
            guard preparedHostKeys.insert(hostKey).inserted else { continue }

            let forTarget = items.filter { $0.targetID == entry.combatantID }
            guard !forTarget.isEmpty else { continue }

            let due = forTarget.filter { $0.availableAt <= now }
            if !due.isEmpty {
                let groups = CombatFeedbackOverlayPolicy.visibleActionGroups(from: due)
                for canvasItem in CombatFeedbackOverlayPolicy.canvasItems(from: groups) {
                    _ = CombatFeedbackRasterPool.shared.prepare(
                        for: canvasItem,
                        dynamicTypeSize: entry.dynamicTypeSize,
                        displayScale: entry.displayScale
                    )
                }
            }

            let upcoming = forTarget.filter { $0.availableAt > now }
            if !upcoming.isEmpty {
                CombatFeedbackRasterPool.shared.prepareAll(
                    for: upcoming,
                    dynamicTypeSize: entry.dynamicTypeSize,
                    displayScale: entry.displayScale,
                    useFrameBudget: true
                )
            }
        }
    }

    private static func scheduleStaggeredRefresh(for items: [CombatFeedbackItem]) {
        pendingStaggerTask?.cancel()
        let now = Date()
        let futureDates = Set(
            items.compactMap { item -> Date? in
                item.availableAt > now ? item.availableAt : nil
            }
        ).sorted()
        guard !futureDates.isEmpty else { return }
        pendingStaggerTask = Task { @MainActor in
            for date in futureDates {
                let delay = date.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                flushRelevantHosts()
            }
            pendingStaggerTask = nil
        }
    }

    /// Refreshes hosts that either have active/expiring items or are currently
    /// presenting a chip (so expiry clears without waking idle panes).
    private static func flushRelevantHosts() {
        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.chipFlush
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.chipFlush,
                intervalState
            )
        }
        let now = Date()
        let activeTargetIDs = Set(
            latestItems.lazy
                .filter { now < $0.expiresAt }
                .map(\.targetID)
        )
        for key in Array(hosts.keys) {
            guard let entry = hosts[key] else { continue }
            let presenting = entry.view?.isPresenting == true
            guard activeTargetIDs.contains(entry.combatantID) || presenting else {
                continue
            }
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
        let visible = latestItems.filter { item in
            item.targetID == entry.combatantID
                && now >= item.availableAt
                && now < item.expiresAt
        }
        let groups = CombatFeedbackOverlayPolicy.visibleActionGroups(from: visible)
        let canvasItems = CombatFeedbackOverlayPolicy.canvasItems(from: groups)
        let chips: [(canvasItem: CombatFeedbackCanvasItem, raster: CombatFeedbackRaster?)] =
            canvasItems.map { canvasItem in
                if CombatFeedbackRasterPool.shared.cachedRaster(
                    for: canvasItem,
                    dynamicTypeSize: entry.dynamicTypeSize,
                    displayScale: entry.displayScale
                ) == nil {
                    _ = CombatFeedbackRasterPool.shared.prepare(
                        for: canvasItem,
                        dynamicTypeSize: entry.dynamicTypeSize,
                        displayScale: entry.displayScale
                    )
                }
                let raster = CombatFeedbackRasterPool.shared.cachedRaster(
                    for: canvasItem,
                    dynamicTypeSize: entry.dynamicTypeSize,
                    displayScale: entry.displayScale
                )
                return (canvasItem, raster)
            }
        view.apply(chips: chips)
    }
}
