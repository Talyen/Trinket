import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

extension BattleSession {
    func markCinematicPlaying() {
        guard var cinematic = activeCinematic, cinematic.phase == .expanding else { return }
        cinematic.phase = .playing
        activeCinematic = cinematic
    }

    func requestSkipCinematic(at date: Date = .now) {
        guard activeCinematic != nil else { return }
        guard date >= (activeCinematic?.skipArmedAt ?? .distantPast) else { return }
        guard options?.canSkipUltimateCinematic() ?? true else { return }
        beginCinematicCollapse()
    }

    func completeCinematicCollapse(expectedID: Int? = nil, at date: Date = .now) {
        guard let cinematic = activeCinematic else { return }
        // Ignore stale collapse tasks from a prior cinematic (unstructured sleep can outlive
        // the overlay that started them).
        if let expectedID, cinematic.id != expectedID {
            return
        }
        actorsWhoPresentedUltimateThisBattle.insert(cinematic.actorID)
        activeCinematic = nil
        presentationHoldCount = max(0, presentationHoldCount - 1)
        let deferred = deferredFeedbackEvents
        deferredFeedbackEvents = []
        recordFeedbackEvents(deferred, at: date, stagger: TrinketMotion.Battle.ultimateChipStagger)
        presentDeferredOutcomeIfNeeded(at: date)
    }

    /// Outcome chrome (or claimed-stage auto-complete) waits until Ultimate collapse finishes.
    private func presentDeferredOutcomeIfNeeded(at date: Date) {
        switch outcome {
        case .victory:
            if let journey = autoEndJourney,
               Self.stageRewardsAlreadyClaimed(
                stageID: activeBattle?.stageID,
                journey: journey
               ) {
                onTurnAutoEnded?(state?.earnedGold ?? 0)
                return
            }
            if victorySummary != nil, !isShowingVictory {
                scheduleVictoryPresentation(after: date)
                return
            }
        case .defeat:
            if !isShowingDefeat {
                scheduleDefeatPresentation(after: date)
                return
            }
        case .none:
            break
        }
        scheduleAutoEndIfNeeded()
    }

    func beginCinematicCollapse() {
        guard var cinematic = activeCinematic, cinematic.phase != .collapsing else { return }
        cinematic.phase = .collapsing
        activeCinematic = cinematic
    }

    func handleOutcomeIfNeeded(
        at date: Date,
        journey: JourneyProgressState,
        homestead: PlayerHomesteadState
    ) -> Int? {
        guard let configuration = activeBattle else { return nil }
        switch outcome {
        case .victory:
            if Self.stageRewardsAlreadyClaimed(
                stageID: configuration.stageID,
                journey: journey
            ) {
                // Keep the Ultimate on screen; collapse fires claimed-stage auto-complete.
                if activeCinematic != nil {
                    return nil
                }
                return state?.earnedGold ?? 0
            }
            guard let battleState = state else { return nil }
            victorySummary = BattleVictorySummary.make(
                configuration: configuration,
                state: battleState,
                homestead: homestead
            )
            // Defer outcome chrome until Ultimate collapse so the killing blow finishes.
            if activeCinematic == nil {
                scheduleVictoryPresentation(after: date)
            }
            return nil
        case .defeat:
            if activeCinematic == nil {
                scheduleDefeatPresentation(after: date)
            }
            return nil
        case .none:
            return nil
        }
    }

    func scheduleVictoryPresentation(after date: Date) {
        scheduleOutcomePresentation(
            after: date,
            expected: .victory,
            sfx: SFXID.victory
        ) { session in
            session.isShowingVictory = true
        }
    }

    func scheduleDefeatPresentation(after date: Date) {
        scheduleOutcomePresentation(
            after: date,
            expected: .defeat,
            sfx: SFXID.defeat
        ) { session in
            session.isShowingDefeat = true
        }
    }

    private func scheduleOutcomePresentation(
        after date: Date,
        expected: BattleSimulationOutcome,
        sfx: SFXID,
        show: @escaping @MainActor (BattleSession) -> Void
    ) {
        pendingOutcomePresentationTask?.cancel()
        let latestFeedbackDelay = activeFeedbackItems
            .map { max(0, $0.expiresAt.timeIntervalSince(date)) }
            .max() ?? 0
        let spectacleDelay = max(TrinketMotion.Battle.cardActivationDuration, latestFeedbackDelay)
            + TrinketMotion.Battle.outcomePresentationPadding
        let delay = outcomePresentationDelayOverride ?? spectacleDelay
        guard delay > 0 else {
            show(self)
            playSFX(sfx)
            return
        }
        pendingOutcomePresentationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, outcome == expected else { return }
            show(self)
            playSFX(sfx)
            pendingOutcomePresentationTask = nil
        }
    }

    func presentResolvedEvents(_ events: [ActionEvent], at date: Date) {
        let nonMilestone = events.filter { $0.kind != .milestone }
        guard let state else {
            recordFeedbackEvents(nonMilestone, at: date, stagger: TrinketMotion.Battle.feedbackStagger)
            return
        }
        let heroID = state.hero.id
        let companionID = state.companion.id

        if let ultimate = nonMilestone.first(where: {
            BattleSpectaclePolicy.shouldPresentUltimateCinematic(
                for: $0,
                heroID: heroID,
                companionID: companionID
            )
        }) {
            let autoSkip = options?.shouldAutoSkipUltimateCinematic(
                actorID: ultimate.actorID,
                actorsWhoPresentedThisBattle: actorsWhoPresentedUltimateThisBattle
            ) ?? false
            if autoSkip {
                recordFeedbackEvents(nonMilestone, at: date, stagger: TrinketMotion.Battle.feedbackStagger)
                return
            }
            deferredFeedbackEvents = nonMilestone
            beginCinematic(from: ultimate, at: date)
            return
        }

        recordFeedbackEvents(nonMilestone, at: date, stagger: TrinketMotion.Battle.feedbackStagger)
        presentCallouts(from: nonMilestone, heroID: heroID, companionID: companionID, at: date)
    }

    func beginCinematic(from event: ActionEvent, at date: Date) {
        nextSpectacleID += 1
        presentationHoldCount += 1
        activeCinematic = BattleCinematicPresentation(
            id: nextSpectacleID,
            actorID: event.actorID,
            actorName: event.actorName,
            abilityID: event.abilityID,
            abilityName: event.abilityName,
            keyword: event.keyword,
            phase: .expanding,
            startedAt: date,
            skipArmedAt: date.addingTimeInterval(TrinketMotion.Battle.ultimateSkipLockout)
        )
        BattleCinematicPlayer.shared.warm(abilityID: event.abilityID)
    }

    func presentCallouts(
        from events: [ActionEvent],
        heroID: String,
        companionID: String,
        at date: Date
    ) {
        let calloutEvent = events.first {
            BattleSpectaclePolicy.shouldPresentSkillCallout(for: $0)
                || BattleSpectaclePolicy.shouldPresentEnemyUltimateAsCallout(
                    for: $0,
                    heroID: heroID,
                    companionID: companionID
                )
        }
        guard let calloutEvent else { return }
        nextSpectacleID += 1
        let hold = TrinketMotion.Battle.skillSoftHold
        softHoldUntil = date.addingTimeInterval(hold)
        activeSkillCallout = SkillCalloutPresentation(
            id: nextSpectacleID,
            actorID: calloutEvent.actorID,
            abilityID: calloutEvent.abilityID,
            abilityName: calloutEvent.abilityName,
            keyword: calloutEvent.keyword,
            expiresAt: date.addingTimeInterval(max(hold, TrinketMotion.Battle.skillCalloutTotal))
        )
    }

    func clearAllPresentation() {
        clearOutcomePresentation()
        preview = nil
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
        clearFeedback()
        clearSpectacle()
        presentationHoldCount = 0
    }

    func recordFeedbackEvents(
        _ events: [ActionEvent],
        at date: Date = .now,
        stagger: TimeInterval
    ) {
        for event in events {
            activeFeedbackEvents.append(event)
            feedbackEventRecordedAt[event.id] = date
        }

        let items = CombatFeedbackPresenter.makeItems(from: events, at: date, stagger: stagger)
        activeFeedbackItems.append(contentsOf: items)
        applyImmediatePresentation(for: items, at: date)
        scheduleFeedbackPresentation(for: items, at: date)
        scheduleFeedbackPruneIfNeeded(at: date)
    }

    /// Applies delayed haptics, SFX, hit reactions, and particle requests on the
    /// same frame that a synchronized action group becomes visible.
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
                applyImmediatePresentation(for: activeGroup, at: .now)
                pendingFeedbackPresentationTasks.removeValue(forKey: actionGroupID)
            }
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

    func applyImmediatePresentation(for items: [CombatFeedbackItem], at date: Date) {
        let due = items.filter { $0.availableAt <= date && !presentedFeedbackIDs.contains($0.id) }
        guard !due.isEmpty else { return }

        for clipID in CombatSFXMapper.uniqueClipIDs(for: due) {
            playSFX(clipID)
        }

        for item in due {
            presentedFeedbackIDs.insert(item.id)
        }

        let groups = Dictionary(grouping: due, by: \.actionGroupID)
        for group in groups.values {
            if let reaction = CombatFeedbackPresenter.reaction(for: group),
               let targetID = group.first?.targetID {
                hitReactionsByTargetID[targetID] = reaction
            }
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
    }

    func playSFX(_ id: String) {
        guard let sfxPlayer else { return }
        sfxPlayer.play(id, volume: options?.effectsVolume ?? 0)
    }

    func clearFeedback() {
        pendingFeedbackPruneTask?.cancel()
        pendingFeedbackPruneTask = nil
        for task in pendingFeedbackPresentationTasks.values {
            task.cancel()
        }
        pendingFeedbackPresentationTasks = [:]
        activeFeedbackEvents = []
        activeFeedbackItems = []
        feedbackEventRecordedAt = [:]
        hitReactionsByTargetID = [:]
        keywordBurstsByTargetID = [:]
        presentedFeedbackIDs = []
    }

    func clearSpectacle() {
        activeSkillCallout = nil
        activeCinematic = nil
        deferredFeedbackEvents = []
        softHoldUntil = nil
        actorsWhoPresentedUltimateThisBattle = []
        BattleCinematicPlayer.shared.releaseAll()
    }

    func pruneExpiredSkillCallout(at date: Date) {
        guard let activeSkillCallout, date >= activeSkillCallout.expiresAt else { return }
        self.activeSkillCallout = nil
    }

    func pruneSoftHold(at date: Date) {
        guard let softHoldUntil, date >= softHoldUntil else { return }
        self.softHoldUntil = nil
    }

    func scheduleAutoEndIfNeeded() {
        cancelPendingAutoEnd()
        guard canEndTurn, !hasPlayableCard,
              let journey = autoEndJourney,
              let homestead = autoEndHomestead else { return }

        let delay = autoEndTurnDelay
        pendingAutoEndTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            guard canEndTurn, !hasPlayableCard else { return }
            let earnedGold = endTurn(journey: journey, homestead: homestead)
            onTurnAutoEnded?(earnedGold)
        }
    }

    func cancelPendingAutoEnd() {
        pendingAutoEndTask?.cancel()
        pendingAutoEndTask = nil
    }

    func resetRun(from configuration: ActiveBattleConfiguration) {
        cancelPendingAutoEnd()
        sfxPlayer?.warm(SFXID.battlePrewarmIDs, concurrentPlayerCount: 2)
        state = BattleState(
            hero: configuration.hero.combatant,
            companion: configuration.companion.combatant,
            enemy: configuration.enemy,
            heroModifiers: configuration.hero.modifiers,
            companionModifiers: configuration.companion.modifiers,
            enemyModifiers: configuration.enemyModifiers,
            rngSeed: configuration.rngSeed,
            tracksLog: false
        )
        clearFeedback()
        clearSpectacle()
        clearOutcomePresentation()
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
        playSFX(SFXID.abilityDraw) // opening hand
        BattleCinematicPlayer.shared.warmLoadout(
            heroUltimateID: configuration.hero.combatant.abilityLoadout.ultimate?.id,
            companionUltimateID: configuration.companion.combatant.abilityLoadout.ultimate?.id
        )
    }

    func clearRunState() {
        cancelPendingAutoEnd()
        onTurnAutoEnded = nil
        autoEndJourney = nil
        autoEndHomestead = nil
        state = nil
        clearFeedback()
        clearSpectacle()
        clearOutcomePresentation()
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
        presentationHoldCount = 0
    }
}
