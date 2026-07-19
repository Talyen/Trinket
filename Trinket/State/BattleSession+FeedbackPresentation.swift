import BattleEngine
import Foundation
import TrinketDesignSystem

extension BattleSession {
    func recordFeedbackEvents(
        _ events: [ActionEvent],
        at date: Date = .now
    ) {
        for event in events {
            feedbackEventRecordedAt[event.id] = date
        }

        let prepared = CombatFeedbackPresenter.makeItems(from: events, at: date)
        guard !prepared.isEmpty else { return }
        var items: [CombatFeedbackItem] = []
        items.reserveCapacity(prepared.count)
        var latestExpiry = date
        for item in prepared {
            let scheduled = scheduleFeedbackItem(item, at: date)
            items.append(scheduled)
            presentedFeedbackIDs.insert(scheduled.id)
            latestExpiry = max(latestExpiry, scheduled.expiresAt)
        }

        activeFeedbackItems.append(contentsOf: items)
        // Visuals may be queued, but sound and hit reactions remain tied to impact.
        onFeedbackItemsChanged?(.insert(items))
        applyMultimodalPresentation(for: items)
        updateFeedbackPruneDate(with: latestExpiry)
    }

    func prepareFeedbackScheduler() {
        _ = scheduler()
    }

    /// Picks a horizontal lane and sequential start for one chip on its target.
    /// Party (hero/companion) uses middle only; enemies prefer middle when free,
    /// otherwise earliest nextStart among all lanes (tie: middle > left > right).
    private func scheduleFeedbackItem(
        _ item: CombatFeedbackItem,
        at date: Date
    ) -> CombatFeedbackItem {
        var clocks = nextFeedbackVisualStartByTargetLane[item.targetID]
            ?? Array(repeating: Date.distantPast, count: TrinketMotion.Battle.feedbackLaneCount)
        if clocks.count != TrinketMotion.Battle.feedbackLaneCount {
            clocks = Array(repeating: Date.distantPast, count: TrinketMotion.Battle.feedbackLaneCount)
        }

        let eligible = TrinketMotion.Battle.feedbackLanes(
            isPartyMember: isPartyFeedbackTarget(item.targetID)
        )
        let lane: CombatFeedbackLane =
            if eligible.contains(.middle), clocks[CombatFeedbackLane.middle.rawValue] <= date {
                .middle
            } else {
                eligible.min { lhs, rhs in
                    let lhsStart = max(date, clocks[lhs.rawValue])
                    let rhsStart = max(date, clocks[rhs.rawValue])
                    if lhsStart != rhsStart {
                        return lhsStart < rhsStart
                    }
                    return lhs.assignmentPriority < rhs.assignmentPriority
                } ?? .middle
            }

        let start = max(date, clocks[lane.rawValue])
        clocks[lane.rawValue] = start.addingTimeInterval(TrinketMotion.Battle.feedbackQueueStagger)
        nextFeedbackVisualStartByTargetLane[item.targetID] = clocks
        return item.scheduled(at: start, lane: lane)
    }

    /// Hero/companion when battle state is available; otherwise treat as enemy (3 lanes).
    private func isPartyFeedbackTarget(_ targetID: String) -> Bool {
        guard let state else { return false }
        return targetID == state.hero.id || targetID == state.companion.id
    }

    private func updateFeedbackPruneDate(with latestExpiry: Date) {
        let candidate = latestExpiry.addingTimeInterval(0.02)
        if let existing = nextFeedbackPruneAt {
            nextFeedbackPruneAt = max(existing, candidate)
        } else {
            nextFeedbackPruneAt = candidate
        }
        scheduler().schedulePrune(at: nextFeedbackPruneAt)
    }

    private func scheduler() -> BattleFeedbackScheduler {
        let scheduler = feedbackScheduler ?? BattleFeedbackScheduler(session: self)
        feedbackScheduler = scheduler
        return scheduler
    }

    fileprivate func feedbackPruneTimerDidFire() {
        nextFeedbackPruneAt = nil
        pruneExpiredFeedback()
        if let latestExpiry = activeFeedbackItems.map(\.expiresAt).max() {
            nextFeedbackPruneAt = latestExpiry.addingTimeInterval(0.02)
        }
        feedbackScheduler?.schedulePrune(at: nextFeedbackPruneAt)
    }

    /// SFX, hit reactions, and keyword bursts — same frame as chips when due.
    func applyMultimodalPresentation(for due: [CombatFeedbackItem]) {
        guard !due.isEmpty else { return }

        playSFX(ids: CombatSFXMapper.uniqueClipIDs(for: due))

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
            noteHitReactionPresentationChanged()
        }
    }

    func playSFX(_ id: String) {
        playSFX(ids: [id])
    }

    func playSFX(ids: [String]) {
        guard let sfxPlayer else { return }
        guard !ids.isEmpty else { return }
        sfxPlayer.playAll(ids, volume: options?.effectsVolume ?? 0)
    }

    func clearFeedback() {
        let hadPublishedPresentation = !activeFeedbackItems.isEmpty
            || !hitReactionsByTargetID.isEmpty
            || !attackReactionsByCombatantID.isEmpty
            || !keywordBurstsByTargetID.isEmpty
            || !presentedFeedbackIDs.isEmpty
        // Keep the reusable prune timer alive across clears.
        nextFeedbackPruneAt = nil
        nextFeedbackVisualStartByTargetLane.removeAll(keepingCapacity: true)
        feedbackScheduler?.park()
        pendingPartyCelebrateTask?.cancel()
        pendingPartyCelebrateTask = nil
        activeFeedbackItems = []
        feedbackEventRecordedAt = [:]
        if !hitReactionsByTargetID.isEmpty {
            hitReactionsByTargetID = [:]
        }
        if !attackReactionsByCombatantID.isEmpty {
            attackReactionsByCombatantID = [:]
        }
        keywordBurstsByTargetID = [:]
        presentedFeedbackIDs = []
        if hadPublishedPresentation {
            resetFeedbackPresentation()
        }
    }
}

final class BattleFeedbackScheduler {
    private let pruneTimer: Timer
    private let target: FeedbackPruneTarget

    init(session: BattleSession) {
        let target = FeedbackPruneTarget(session: session)
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
    private weak var session: BattleSession?

    init(session: BattleSession) {
        self.session = session
    }

    @objc func fire() {
        Task { @MainActor [weak session] in
            session?.feedbackPruneTimerDidFire()
        }
    }
}
