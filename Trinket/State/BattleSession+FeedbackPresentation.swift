import BattleEngine
import Foundation
import TrinketDesignSystem

extension BattleSession {
    func recordFeedbackEvents(
        _ events: [ActionEvent],
        at date: Date = .now,
        stagger: TimeInterval
    ) {
        for event in events {
            feedbackEventRecordedAt[event.id] = date
        }

        let items = CombatFeedbackPresenter.makeItems(from: events, at: date, stagger: stagger)
        activeFeedbackItems.append(contentsOf: items)
        // Chips, SFX, hit reactions, and keyword bursts all fire on impact.
        onFeedbackItemsChanged?(.insert(items))
        applyImmediatePresentation(for: items, at: date)
        scheduleFeedbackPresentation(for: items, at: date)
        scheduleFeedbackPruneIfNeeded(at: date)
    }

    /// Staggered groups become available later — fire their multimodal at
    /// `availableAt` with no extra frame delay.
    func scheduleFeedbackPresentation(for items: [CombatFeedbackItem], at date: Date) {
        let groups = Dictionary(grouping: items, by: \.actionGroupID)
        var didEnqueue = false
        for (_, group) in groups {
            guard let availableAt = group.first?.availableAt, availableAt > date else { continue }
            pendingFeedbackPresentationDates.append(availableAt)
            didEnqueue = true
        }
        guard didEnqueue else { return }
        pendingFeedbackPresentationDates.sort()
        ensureFeedbackPresentationLoopRunning()
    }

    func scheduleFeedbackPruneIfNeeded(at _: Date) {
        if let latestExpiry = activeFeedbackItems.map(\.expiresAt).max() {
            let candidate = latestExpiry.addingTimeInterval(0.02)
            if let existing = nextFeedbackPruneAt {
                nextFeedbackPruneAt = max(existing, candidate)
            } else {
                nextFeedbackPruneAt = candidate
            }
        }
        ensureFeedbackPruneLoopRunning()
        ensureFeedbackPresentationLoopRunning()
    }

    /// One long-lived loop started on first feedback — publish frames only bump
    /// `nextFeedbackPruneAt` (Task allocation on publish was a measured hitch).
    private func ensureFeedbackPruneLoopRunning() {
        guard pendingFeedbackPruneTask == nil else { return }
        pendingFeedbackPruneTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard let fireAt = nextFeedbackPruneAt else {
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }
                let delay = fireAt.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                // Cleared while sleeping — do not prune from a stale wake.
                guard let current = nextFeedbackPruneAt else { continue }
                if current > fireAt {
                    continue
                }
                nextFeedbackPruneAt = nil
                pruneExpiredFeedback()
                if let latestExpiry = activeFeedbackItems.map(\.expiresAt).max() {
                    nextFeedbackPruneAt = latestExpiry.addingTimeInterval(0.02)
                }
            }
        }
    }

    private func ensureFeedbackPresentationLoopRunning() {
        guard pendingFeedbackPresentationLoopTask == nil else { return }
        pendingFeedbackPresentationLoopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard let fireAt = pendingFeedbackPresentationDates.first else {
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }
                let delay = fireAt.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                guard let currentFirst = pendingFeedbackPresentationDates.first else { continue }
                if currentFirst > fireAt {
                    continue
                }
                pendingFeedbackPresentationDates.removeAll { $0 <= fireAt }
                let activeGroup = activeFeedbackItems.filter {
                    $0.availableAt <= fireAt && fireAt < $0.expiresAt
                }
                applyImmediatePresentation(for: activeGroup, at: fireAt)
            }
        }
    }

    /// SFX, hit reactions, and keyword bursts — same frame as chips when due.
    func applyMultimodalPresentation(for due: [CombatFeedbackItem]) {
        guard !due.isEmpty else { return }

        playSFX(ids: CombatSFXMapper.uniqueClipIDs(for: due))

        let groups = Dictionary(grouping: due, by: \.actionGroupID)
        var didPublishReaction = false
        for group in groups.values {
            if let reaction = CombatFeedbackPresenter.reaction(for: group),
               let targetID = group.first?.targetID {
                hitReactionsByTargetID[targetID] = reaction
                didPublishReaction = true
            }
        }
        if didPublishReaction {
            noteHitReactionPresentationChanged()
        }
    }

    func applyImmediatePresentation(for items: [CombatFeedbackItem], at date: Date) {
        let due = items.filter { $0.availableAt <= date && !presentedFeedbackIDs.contains($0.id) }
        guard !due.isEmpty else { return }
        for item in due {
            presentedFeedbackIDs.insert(item.id)
        }
        applyMultimodalPresentation(for: due)
    }

    func playSFX(_ id: String) {
        playSFX(ids: [id])
    }

    func playSFX(ids: [String]) {
        guard let sfxPlayer else { return }
        guard !ids.isEmpty else { return }
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.audioPlayback,
            detail: "clips=\(ids.joined(separator: ","))"
        )
        sfxPlayer.playAll(ids, volume: options?.effectsVolume ?? 0)
    }

    func clearFeedback() {
        let hadPublishedPresentation = !activeFeedbackItems.isEmpty
            || !hitReactionsByTargetID.isEmpty
            || !attackReactionsByCombatantID.isEmpty
            || !keywordBurstsByTargetID.isEmpty
            || !presentedFeedbackIDs.isEmpty
        // Keep prune / staggered-presentation loops alive across clears.
        nextFeedbackPruneAt = nil
        pendingFeedbackPresentationDates.removeAll(keepingCapacity: true)
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
