import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

extension BattleSession {
    func presentCombatantDetail(_ detail: CombatantCardDetail) {
        overlayCombatantDetail = detail
    }

    func presentAbilityDetail(_ ability: Ability) {
        overlayAbilityDetail = ability
    }

    func publishAttackReaction(_ reaction: CombatantAttackReaction, for combatantID: String) {
        attackReactionsByCombatantID[combatantID] = reaction
        noteAttackReactionPresentationChanged()
    }

    func beginAttackWindUp(for combatantID: String) {
        nextSpectacleID += 1
        publishAttackReaction(
            CombatantAttackReaction(id: nextSpectacleID, kind: .attack, phase: .windUp),
            for: combatantID
        )
    }

    func commitAttackSwing(for combatantID: String) {
        nextSpectacleID += 1
        publishAttackReaction(
            CombatantAttackReaction(id: nextSpectacleID, kind: .attack, phase: .swing),
            for: combatantID
        )
    }

    func cancelAttack(for combatantID: String) {
        nextSpectacleID += 1
        publishAttackReaction(
            CombatantAttackReaction(id: nextSpectacleID, kind: .attack, phase: .cancel),
            for: combatantID
        )
    }

    func publishFullAttack(for combatantID: String) {
        nextSpectacleID += 1
        publishAttackReaction(
            CombatantAttackReaction(id: nextSpectacleID, kind: .attack, phase: .full),
            for: combatantID
        )
    }

    /// Resolves a hand-card owner to the live combatant id for attack telegraph.
    func combatantID(for participant: BattleParticipant) -> String? {
        switch participant {
        case .hero:
            presentation.hero?.combatant.id ?? state?.hero.id
        case .companion:
            presentation.companion?.combatant.id ?? state?.companion.id
        case .enemy:
            presentation.enemy?.combatant.id ?? state?.enemy.id
        }
    }

    func markCinematicPlaying() {
        guard var cinematic = activeCinematic, cinematic.phase == .expanding else { return }
        cinematic.phase = .playing
        activeCinematic = cinematic
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
        if !deferredFeedbackEvents.isEmpty {
            deferredFeedbackEvents = []
        }
        recordFeedbackEvents(deferred, at: date)
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
                publishPartyCelebrateReactions(at: date)
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

    func beginCinematicCollapse(expectedID: Int? = nil) {
        guard var cinematic = activeCinematic, cinematic.phase != .collapsing else { return }
        // Ignore stale auto-finish tasks from a prior overlay (fallback hold / video end
        // can outlive the view that scheduled them).
        if let expectedID, cinematic.id != expectedID {
            return
        }
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
                publishPartyCelebrateReactions(at: date)
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
        publishPartyCelebrateReactions(at: date)
        scheduleOutcomePresentation(
            after: date,
            expected: .victory,
            sfx: SFXID.victory
        ) { session in
            session.isShowingVictory = true
        }
    }

    /// Squish/bounce living Hero + Pet cards while the enemy dissolves.
    /// Lands on the frame after dissolve starts so KeyframeAnimator work does not
    /// share the killing-blow chip/layout commit.
    private func publishPartyCelebrateReactions(at date: Date) {
        pendingPartyCelebrateTask?.cancel()
        pendingPartyCelebrateTask = Task { @MainActor [weak self] in
            // One display period past dissolve start (~16 ms) plus a small settle.
            try? await Task.sleep(for: .milliseconds(32))
            guard let self, !Task.isCancelled else { return }
            publishPartyCelebrateReactionsNow(at: date)
        }
    }

    private func publishPartyCelebrateReactionsNow(at date: Date) {
        guard let battleState = state else { return }
        // Negative synthetic IDs stay clear of engine event / feedback item IDs.
        let baseID = -1 * max(1, Int(date.timeIntervalSinceReferenceDate * 1000))
        var didPublish = false
        if battleState.isHeroAlive {
            hitReactionsByTargetID[battleState.hero.id] = CombatantHitReaction(
                id: baseID,
                kind: .celebrate
            )
            didPublish = true
        }
        if battleState.isCompanionAlive {
            hitReactionsByTargetID[battleState.companion.id] = CombatantHitReaction(
                id: baseID &- 1,
                kind: .celebrate
            )
            didPublish = true
        }
        if didPublish {
            noteHitReactionPresentationChanged()
        }
    }

    /// Surfaces victory chrome after a claimed-stage auto-complete persist failure so
    /// the player can retry via Loot All instead of remaining stuck on the battlefield.
    func presentVictoryChromeForPersistRetry(homestead: PlayerHomesteadState) {
        guard outcome == .victory,
              let configuration = activeBattle,
              let battleState = state,
              !isShowingVictory
        else { return }
        if victorySummary == nil {
            victorySummary = BattleVictorySummary.make(
                configuration: configuration,
                state: battleState,
                homestead: homestead
            )
        }
        isShowingVictory = true
    }

    #if DEBUG
    func debugSkipCombat(homestead: PlayerHomesteadState) {
        guard let configuration = activeBattle,
              let battleState = state,
              !isShowingVictory,
              !isShowingDefeat
        else { return }

        cancelPendingAutoEnd()
        cancelOpeningHandDeal()
        pendingOutcomePresentationTask?.cancel()
        pendingOutcomePresentationTask = nil
        clearSpectacle()
        victorySummary = BattleVictorySummary.make(
            configuration: configuration,
            state: battleState,
            homestead: homestead
        )
        isShowingVictory = true
        playSFX(SFXID.victory)
    }
    #endif

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
        sfx: String,
        show: @escaping @MainActor (BattleSession) -> Void
    ) {
        if pendingOutcomePresentationTask != nil, outcome == expected {
            return
        }
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
            recordFeedbackEvents(nonMilestone, at: date)
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
                recordFeedbackEvents(nonMilestone, at: date)
                return
            }
            deferredFeedbackEvents = nonMilestone
            beginCinematic(from: ultimate, at: date)
            // Prune may have suppressed its publish; clear expired chips once.
            noteFeedbackPresentationChanged()
            return
        }

        recordFeedbackEvents(nonMilestone, at: date)
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
            startedAt: date
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
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
        clearFeedback()
        clearSpectacle()
        presentationHoldCount = 0
    }

    func clearSpectacle(releaseCinematicPlayers: Bool = true) {
        if activeSkillCallout != nil {
            activeSkillCallout = nil
        }
        if activeCinematic != nil {
            activeCinematic = nil
        }
        deferredFeedbackEvents = []
        if softHoldUntil != nil {
            softHoldUntil = nil
        }
        if !actorsWhoPresentedUltimateThisBattle.isEmpty {
            actorsWhoPresentedUltimateThisBattle = []
        }
        if releaseCinematicPlayers {
            BattleCinematicPlayer.shared.releaseAll()
        }
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
        guard !isSuspendedForScenePhase,
              canEndTurn, !hasPlayableCard,
              let journey = autoEndJourney,
              let homestead = autoEndHomestead else { return }

        let settleDelay = autoEndTurnDelay
        pendingAutoEndTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(settleDelay))
            guard let self, !Task.isCancelled else { return }
            guard !isSuspendedForScenePhase, canEndTurn, !hasPlayableCard else { return }

            if shouldTelegraphEnemyAttack(), let enemyID = state?.enemy.id {
                publishFullAttack(for: enemyID)
                let impactDelay = enemyAttackImpactDelayOverride
                    ?? CombatFeedbackAttackRecipes.cardAttack(for: .attack).impactDelay
                if impactDelay > 0 {
                    try? await Task.sleep(for: .seconds(impactDelay))
                    guard !Task.isCancelled else { return }
                    guard !isSuspendedForScenePhase, canEndTurn, !hasPlayableCard else { return }
                }
            }

            let earnedGold = endTurn(journey: journey, homestead: homestead)
            onTurnAutoEnded?(earnedGold)
        }
    }

    /// True when the upcoming `endTurn` will have the enemy perform an ability.
    func shouldTelegraphEnemyAttack() -> Bool {
        guard let state else { return false }
        guard state.roster.enemy.isAlive else { return false }
        guard !state.roster.hasPendingActionSkip(for: state.enemy) else { return false }
        return true
    }

    func cancelPendingAutoEnd() {
        pendingAutoEndTask?.cancel()
        pendingAutoEndTask = nil
    }

    func resetRun(from configuration: ActiveBattleConfiguration) {
        cancelPendingAutoEnd()
        cancelOpeningHandDeal()
        if let pendingPreparedRun,
           pendingPreparedRun.configuration.id == configuration.id {
            state = pendingPreparedRun.state
            presentation.install(pendingPreparedRun.presentation)
            self.pendingPreparedRun = nil
        } else {
            installBattleState(
                Self.makeBattleState(from: configuration),
                configurationID: configuration.id
            )
        }
        preparedBattleRunsByToken.removeAll(keepingCapacity: true)
        clearFeedback()
        clearSpectacle(releaseCinematicPlayers: false)
        clearOutcomePresentation()
        if overlayCombatantDetail != nil {
            overlayCombatantDetail = nil
        }
        if overlayAbilityDetail != nil {
            overlayAbilityDetail = nil
        }
        if isShowingBattleLog {
            isShowingBattleLog = false
        }
        beginOpeningHandDeal(for: configuration.id)
    }

    func clearRunState() {
        cancelPendingAutoEnd()
        cancelOpeningHandDeal()
        preparedBattleRunsByToken.removeAll(keepingCapacity: true)
        pendingPreparedRun = nil
        onTurnAutoEnded = nil
        autoEndJourney = nil
        autoEndHomestead = nil
        state = nil
        presentation.clear()
        clearFeedback()
        clearSpectacle()
        clearOutcomePresentation()
        feedbackScheduler?.invalidate()
        feedbackScheduler = nil
        nextFeedbackPruneAt = nil
        nextFeedbackVisualStartByTarget.removeAll(keepingCapacity: true)
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
        presentationHoldCount = 0
    }
}
