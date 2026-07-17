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
        // Frame N: chip publish/flush/host apply stays on-impact.
        onFeedbackItemsChanged?(.insert(items))
        // Frame N+1: reactions, keyword bursts, and SFX — avoids same-frame stacking.
        scheduleMultimodalPresentation(for: items, at: date)
        scheduleFeedbackPresentation(for: items, at: date)
        scheduleFeedbackPruneIfNeeded(at: date)
    }

    /// Applies delayed haptics, SFX, hit reactions, and particle requests one
    /// display frame after chip publish so multimodal work does not share the
    /// ChipPublish / ChipHostApply commit (~16 ms causality tradeoff).
    func scheduleFeedbackPresentation(for items: [CombatFeedbackItem], at date: Date) {
        let groups = Dictionary(grouping: items, by: \.actionGroupID)
        for (actionGroupID, group) in groups {
            guard let availableAt = group.first?.availableAt, availableAt > date else { continue }
            pendingFeedbackPresentationTasks[actionGroupID]?.cancel()
            let delay = max(0, availableAt.timeIntervalSince(date))
            pendingFeedbackPresentationTasks[actionGroupID] = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self, !Task.isCancelled else { return }
                let activeGroup = activeFeedbackItems.filter {
                    $0.actionGroupID == actionGroupID
                }
                scheduleMultimodalPresentation(for: activeGroup, at: .now)
                pendingFeedbackPresentationTasks.removeValue(forKey: actionGroupID)
            }
        }
    }

    /// Defers SFX / hit reactions / keyword bursts by one display period after chips.
    func scheduleMultimodalPresentation(for items: [CombatFeedbackItem], at date: Date) {
        let due = items.filter { $0.availableAt <= date && !presentedFeedbackIDs.contains($0.id) }
        guard !due.isEmpty else { return }

        for item in due {
            presentedFeedbackIDs.insert(item.id)
        }

        let taskID = due.map(\.id).min() ?? 0
        pendingMultimodalPresentationTasks[taskID]?.cancel()
        pendingMultimodalPresentationTasks[taskID] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(16))
            guard let self, !Task.isCancelled else { return }
            applyDeferredMultimodalPresentation(for: due)
            pendingMultimodalPresentationTasks.removeValue(forKey: taskID)
        }
    }

    func scheduleFeedbackPruneIfNeeded(at date: Date) {
        pendingFeedbackPruneTask?.cancel()
        guard let latestExpiry = activeFeedbackItems.map(\.expiresAt).max() else { return }
        let delay = max(0, latestExpiry.timeIntervalSince(date)) + 0.02
        pendingFeedbackPruneTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            pruneExpiredFeedback()
        }
    }

    /// SFX, hit reactions, and keyword bursts — invoked one frame after chip publish.
    func applyDeferredMultimodalPresentation(for due: [CombatFeedbackItem]) {
        guard !due.isEmpty else { return }

        for clipID in CombatSFXMapper.uniqueClipIDs(for: due) {
            playSFX(clipID)
        }

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

        let bursts = CombatFeedbackPresenter.bursts(for: due)
        for burst in bursts {
            guard let targetID = due.first(where: { $0.id == burst.id })?.targetID else { continue }
            var existing = keywordBurstsByTargetID[targetID, default: []]
            existing.append(burst)
            if existing.count > TrinketMotion.Battle.maxKeywordBurstsPerPane {
                existing = Array(existing.suffix(TrinketMotion.Battle.maxKeywordBurstsPerPane))
            }
            keywordBurstsByTargetID[targetID] = existing
        }
        if !bursts.isEmpty {
            noteBurstPresentationChanged()
        }
    }

    /// Kept for call sites that still want synchronous multimodal apply (tests / prune).
    func applyImmediatePresentation(for items: [CombatFeedbackItem], at date: Date) {
        let due = items.filter { $0.availableAt <= date && !presentedFeedbackIDs.contains($0.id) }
        guard !due.isEmpty else { return }
        for item in due {
            presentedFeedbackIDs.insert(item.id)
        }
        applyDeferredMultimodalPresentation(for: due)
    }

    func playSFX(_ id: String) {
        guard let sfxPlayer else { return }
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.audioPlayback,
            detail: "clip=\(id)"
        )
        sfxPlayer.play(id, volume: options?.effectsVolume ?? 0)
    }

    func clearFeedback() {
        let hadPublishedPresentation = !activeFeedbackItems.isEmpty
            || !hitReactionsByTargetID.isEmpty
            || !keywordBurstsByTargetID.isEmpty
            || !presentedFeedbackIDs.isEmpty
        pendingFeedbackPruneTask?.cancel()
        pendingFeedbackPruneTask = nil
        pendingPartyCelebrateTask?.cancel()
        pendingPartyCelebrateTask = nil
        for task in pendingFeedbackPresentationTasks.values {
            task.cancel()
        }
        pendingFeedbackPresentationTasks = [:]
        for task in pendingMultimodalPresentationTasks.values {
            task.cancel()
        }
        pendingMultimodalPresentationTasks = [:]
        activeFeedbackItems = []
        feedbackEventRecordedAt = [:]
        if !hitReactionsByTargetID.isEmpty {
            hitReactionsByTargetID = [:]
        }
        keywordBurstsByTargetID = [:]
        presentedFeedbackIDs = []
        if hadPublishedPresentation {
            resetFeedbackPresentation()
        }
    }
}
