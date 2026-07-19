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
            let queuedStart = nextFeedbackVisualStartByTargetID[item.targetID] ?? date
            let start = max(date, queuedStart)
            nextFeedbackVisualStartByTargetID[item.targetID] = start.addingTimeInterval(
                TrinketMotion.Battle.feedbackQueueStagger
            )
            let scheduled = item.scheduled(at: start)
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
        nextFeedbackVisualStartByTargetID.removeAll(keepingCapacity: true)
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
    private var pruneTimer: Timer!
    private var target: FeedbackPruneTarget!

    init(session: BattleSession) {
        let target = FeedbackPruneTarget(session: session)
        self.target = target
        pruneTimer = Timer(
            timeInterval: 86400,
            target: target,
            selector: #selector(FeedbackPruneTarget.fire),
            userInfo: nil,
            repeats: false
        )
        pruneTimer.fireDate = .distantFuture
        RunLoop.main.add(pruneTimer, forMode: .common)
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
        pruneTimer?.invalidate()
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
