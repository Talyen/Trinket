import BattleEngine
import Foundation
import Observation
import TrinketBattleRuntime
import TrinketDesignSystem
import TrinketFeatureSupport

/// Independently observable, performance-sensitive combat feedback lane.
@MainActor
@Observable
final class BattleFeedbackLane {
    private(set) var burstEpoch = 0
    private(set) var hitReactionEpoch = 0
    private(set) var attackReactionEpoch = 0

    @ObservationIgnored
    var activeItems: [CombatFeedbackItem] = []
    @ObservationIgnored
    var hitReactionsByTargetID: [String: CombatantHitReaction] = [:]
    @ObservationIgnored
    var attackReactionsByCombatantID: [String: CombatantAttackReaction] = [:]
    @ObservationIgnored
    var keywordBurstsByTargetID: [String: [KeywordBurstRequest]] = [:]
    @ObservationIgnored
    var eventRecordedAt: [Int: Date] = [:]
    @ObservationIgnored
    var presentedEventIDs: Set<Int> = []
    @ObservationIgnored
    var nextVisualStartByTarget: [String: Date] = [:]
    @ObservationIgnored
    var nextPruneAt: Date?
    @ObservationIgnored
    var scheduler: BattleFeedbackScheduler?

    @ObservationIgnored
    private var bridges: [(
        ownerID: UUID,
        onChange: (CombatFeedbackUpdate) -> Void
    )] = []

    var latestExpiry: Date? {
        activeItems.map(\.expiresAt).max()
    }

    func installBridge(
        ownerID: UUID,
        onChange: @escaping (CombatFeedbackUpdate) -> Void
    ) {
        bridges.removeAll { $0.ownerID == ownerID }
        bridges.append((ownerID, onChange))
    }

    func uninstallBridge(ownerID: UUID) {
        bridges.removeAll { $0.ownerID == ownerID }
    }

    func publish(_ update: CombatFeedbackUpdate) {
        for bridge in bridges {
            bridge.onChange(update)
        }
    }

    func noteItemsChanged() {
        publish(.replace(activeItems))
    }

    func noteBurstsChanged() {
        burstEpoch &+= 1
    }

    func noteHitReactionsChanged() {
        hitReactionEpoch &+= 1
    }

    func noteAttackReactionsChanged() {
        attackReactionEpoch &+= 1
    }

    func resetPresentation() {
        burstEpoch &+= 1
        hitReactionEpoch &+= 1
        attackReactionEpoch &+= 1
        publish(.reset)
    }

    func record(
        _ events: [ActionEvent],
        at date: Date = .now,
        environment: BattleRuntimeDependencies = .silent
    ) {
        for event in events {
            eventRecordedAt[event.id] = date
        }

        let prepared = CombatFeedbackPresenter.makeItems(from: events, at: date)
        guard !prepared.isEmpty else { return }
        var items: [CombatFeedbackItem] = []
        items.reserveCapacity(prepared.count)
        var latestExpiry = date
        for item in prepared {
            let scheduled = schedule(item, at: date)
            items.append(scheduled)
            presentedEventIDs.insert(scheduled.id)
            latestExpiry = max(latestExpiry, scheduled.expiresAt)
        }

        activeItems.append(contentsOf: items)
        publish(.insert(items))
        applyMultimodalPresentation(for: items, environment: environment)
        updatePruneDate(with: latestExpiry)
    }

    func prepareScheduler() {
        _ = resolvedScheduler()
    }

    func keywordBursts(for targetID: String, at date: Date = .now) -> [KeywordBurstRequest] {
        (keywordBurstsByTargetID[targetID] ?? []).filter { burst in
            date >= burst.availableAt && date < burst.expiresAt
        }
    }

    func removeEvent(_ id: Int, noteChange: Bool = true) {
        if let item = activeItems.first(where: { $0.sourceEventIDs.contains(id) }) {
            let sourceEventIDs = Set(item.sourceEventIDs)
            keywordBurstsByTargetID[item.targetID]?.removeAll { $0.id == item.id }
            let clearedReaction = hitReactionsByTargetID[item.targetID]?.id == item.id
            if clearedReaction {
                hitReactionsByTargetID.removeValue(forKey: item.targetID)
            }
            activeItems.removeAll { $0.id == item.id }
            for sourceEventID in sourceEventIDs {
                eventRecordedAt.removeValue(forKey: sourceEventID)
                presentedEventIDs.remove(sourceEventID)
            }
            if clearedReaction {
                noteHitReactionsChanged()
            }
            if noteChange {
                publish(.remove([item.id]))
            }
            return
        }
        eventRecordedAt.removeValue(forKey: id)
        presentedEventIDs.remove(id)
    }

    func pruneExpired(at date: Date = .now, notifyPresentation: Bool = true) {
        let expiredItemIDs = activeItems.compactMap { item in
            date >= item.expiresAt ? item.id : nil
        }
        var removedItemIDs: Set<Int> = []
        for eventID in expiredItemIDs {
            let beforeCount = activeItems.count
            removeEvent(eventID, noteChange: false)
            if activeItems.count != beforeCount {
                removedItemIDs.insert(eventID)
            }
        }

        let maxRawLifetime = TrinketMotion.Battle.maxChipLifetime
        let expiredRawIDs: [Int] = eventRecordedAt.compactMap { entry -> Int? in
            let (eventID, recordedAt) = entry
            guard date.timeIntervalSince(recordedAt) >= maxRawLifetime else { return nil }
            let hasScheduledItem = activeItems.contains { $0.sourceEventIDs.contains(eventID) }
            return hasScheduledItem ? nil : eventID
        }
        for eventID in expiredRawIDs {
            removeEvent(eventID, noteChange: false)
        }

        var prunedBursts = false
        for (targetID, bursts) in keywordBurstsByTargetID {
            let kept = bursts.filter { date < $0.expiresAt }
            if kept.count != bursts.count {
                keywordBurstsByTargetID[targetID] = kept
                prunedBursts = true
            }
        }
        if !removedItemIDs.isEmpty, notifyPresentation {
            publish(.remove(removedItemIDs))
        }
        if prunedBursts {
            noteBurstsChanged()
        }
    }

    func clear() {
        let hadPublishedPresentation = !activeItems.isEmpty
            || !hitReactionsByTargetID.isEmpty
            || !attackReactionsByCombatantID.isEmpty
            || !keywordBurstsByTargetID.isEmpty
            || !presentedEventIDs.isEmpty
        nextPruneAt = nil
        nextVisualStartByTarget.removeAll(keepingCapacity: true)
        scheduler?.park()
        activeItems = []
        eventRecordedAt = [:]
        hitReactionsByTargetID = [:]
        attackReactionsByCombatantID = [:]
        keywordBurstsByTargetID = [:]
        presentedEventIDs = []
        if hadPublishedPresentation {
            resetPresentation()
        }
    }

    func release() {
        clear()
        scheduler?.invalidate()
        scheduler = nil
    }

    private func schedule(
        _ item: CombatFeedbackItem,
        at date: Date
    ) -> CombatFeedbackItem {
        let start = max(date, nextVisualStartByTarget[item.targetID] ?? .distantPast)
        nextVisualStartByTarget[item.targetID] = start.addingTimeInterval(
            TrinketMotion.Battle.feedbackStreamStagger
        )
        return item.scheduled(at: start)
    }

    private func updatePruneDate(with latestExpiry: Date) {
        let candidate = latestExpiry.addingTimeInterval(0.02)
        if let existing = nextPruneAt {
            nextPruneAt = max(existing, candidate)
        } else {
            nextPruneAt = candidate
        }
        resolvedScheduler().schedulePrune(at: nextPruneAt)
    }

    private func resolvedScheduler() -> BattleFeedbackScheduler {
        let scheduler = scheduler ?? BattleFeedbackScheduler(lane: self)
        self.scheduler = scheduler
        return scheduler
    }

    fileprivate func pruneTimerDidFire() {
        nextPruneAt = nil
        pruneExpired()
        if let latestExpiry {
            nextPruneAt = latestExpiry.addingTimeInterval(0.02)
        }
        scheduler?.schedulePrune(at: nextPruneAt)
    }

    private func applyMultimodalPresentation(
        for due: [CombatFeedbackItem],
        environment: BattleRuntimeDependencies
    ) {
        guard !due.isEmpty else { return }

        environment.playSFX(CombatSFXMapper.uniqueClipIDs(for: due))

        var didPublishReaction = false
        var reactedActionIDs = Set<Int>()
        for item in due where item.presentationIndex == 0
            && item.reactionKind != .none
            && reactedActionIDs.insert(item.actionGroupID).inserted {
            hitReactionsByTargetID[item.targetID] = CombatantHitReaction(
                id: item.id,
                kind: item.reactionKind
            )
            didPublishReaction = true
        }
        if didPublishReaction {
            noteHitReactionsChanged()
        }
    }
}

final class BattleFeedbackScheduler {
    private let pruneTimer: Timer
    private let target: FeedbackPruneTarget

    init(lane: BattleFeedbackLane) {
        let target = FeedbackPruneTarget(lane: lane)
        self.target = target
        let pruneTimer = Timer(
            timeInterval: 86400,
            target: target,
            selector: #selector(FeedbackPruneTarget.fire),
            userInfo: nil,
            repeats: false
        )
        pruneTimer.fireDate = .distantFuture
        RunLoop.main.add(pruneTimer, forMode: .common)
        self.pruneTimer = pruneTimer
    }

    func schedulePrune(at date: Date?) {
        pruneTimer.fireDate = date ?? .distantFuture
    }

    func park() {
        pruneTimer.fireDate = .distantFuture
    }

    func invalidate() {
        pruneTimer.invalidate()
    }

    deinit {
        pruneTimer.invalidate()
    }
}

private final class FeedbackPruneTarget: NSObject {
    private weak var lane: BattleFeedbackLane?

    init(lane: BattleFeedbackLane) {
        self.lane = lane
    }

    @objc func fire() {
        Task { @MainActor [weak lane] in
            lane?.pruneTimerDidFire()
        }
    }
}
