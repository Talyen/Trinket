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

    func completeCinematicCollapse(at date: Date = .now) {
        guard let cinematic = activeCinematic else { return }
        actorsWhoPresentedUltimateThisBattle.insert(cinematic.actorID)
        activeCinematic = nil
        presentationHoldCount = max(0, presentationHoldCount - 1)
        let deferred = deferredFeedbackEvents
        deferredFeedbackEvents = []
        recordFeedbackEvents(deferred, at: date, stagger: CombatFeedbackTiming.ultimateChipStagger)
        scheduleAutoEndIfNeeded()
    }

    func beginCinematicCollapse() {
        guard var cinematic = activeCinematic, cinematic.phase != .collapsing else { return }
        cinematic.phase = .collapsing
        activeCinematic = cinematic
    }

    func handleOutcomeIfNeeded(
        at _: Date,
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
                return state?.earnedGold ?? 0
            }
            guard let battleState = state else { return nil }
            victorySummary = BattleVictorySummary.make(
                configuration: configuration,
                state: battleState,
                homestead: homestead
            )
            isShowingVictory = true
            playSFX(SFXID.victory)
            return nil
        case .defeat:
            isShowingDefeat = true
            playSFX(SFXID.defeat)
            return nil
        case .none:
            return nil
        }
    }

    func presentResolvedEvents(_ events: [ActionEvent], at date: Date) {
        let nonMilestone = events.filter { $0.kind != .milestone }
        guard let state else {
            recordFeedbackEvents(nonMilestone, at: date, stagger: 0)
            return
        }
        let heroID = state.hero.id
        let petID = state.pet.id

        if let ultimate = nonMilestone.first(where: {
            BattleSpectaclePolicy.shouldPresentUltimateCinematic(
                for: $0,
                heroID: heroID,
                petID: petID
            )
        }) {
            let autoSkip = options?.shouldAutoSkipUltimateCinematic(
                actorID: ultimate.actorID,
                actorsWhoPresentedThisBattle: actorsWhoPresentedUltimateThisBattle
            ) ?? false
            if autoSkip {
                recordFeedbackEvents(nonMilestone, at: date, stagger: 0)
                return
            }
            deferredFeedbackEvents = nonMilestone
            beginCinematic(from: ultimate, at: date)
            return
        }

        recordFeedbackEvents(nonMilestone, at: date, stagger: 0)
        presentCallouts(from: nonMilestone, heroID: heroID, petID: petID, at: date)
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
        petID: String,
        at date: Date
    ) {
        let calloutEvent = events.first {
            BattleSpectaclePolicy.shouldPresentSkillCallout(for: $0)
                || BattleSpectaclePolicy.shouldPresentEnemyUltimateAsCallout(
                    for: $0,
                    heroID: heroID,
                    petID: petID
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
        scheduleFeedbackPruneIfNeeded(at: date)
    }

    func scheduleFeedbackPruneIfNeeded(at date: Date) {
        pendingFeedbackPruneTask?.cancel()
        guard let latestExpiry = activeFeedbackItems.map(\.expiresAt).max() else { return }
        let delay = max(0, latestExpiry.timeIntervalSince(date)) + 0.02
        pendingFeedbackPruneTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.pruneExpiredFeedback()
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
            if let reaction = CombatFeedbackPresenter.reaction(for: [item]) {
                hitReactionsByTargetID[item.targetID] = reaction
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

        let delay = Self.autoEndTurnDelay
        pendingAutoEndTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            guard self.canEndTurn, !self.hasPlayableCard else { return }
            let earnedGold = self.endTurn(journey: journey, homestead: homestead)
            self.onTurnAutoEnded?(earnedGold)
        }
    }

    func cancelPendingAutoEnd() {
        pendingAutoEndTask?.cancel()
        pendingAutoEndTask = nil
    }

    func resetRun(from configuration: ActiveBattleConfiguration) {
        cancelPendingAutoEnd()
        state = BattleState(
            hero: configuration.hero.combatant,
            pet: configuration.pet.combatant,
            enemy: configuration.enemy,
            heroModifiers: configuration.hero.modifiers,
            petModifiers: configuration.pet.modifiers,
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
            petUltimateID: configuration.pet.combatant.abilityLoadout.ultimate?.id
        )
    }

    func clearRunState() {
        cancelPendingAutoEnd()
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
