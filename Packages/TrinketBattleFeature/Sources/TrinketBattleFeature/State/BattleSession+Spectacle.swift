import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

extension BattleSession {
    public func presentCombatantDetail(_ detail: CombatantCardDetail) {
        overlayCombatantDetail = detail
    }

    public func presentAbilityDetail(_ ability: Ability) {
        overlayAbilityDetail = ability
    }

    func publishAttackReaction(_ reaction: CombatantAttackReaction, for combatantID: String) {
        feedback.attackReactionsByCombatantID[combatantID] = reaction
        feedback.noteAttackReactionsChanged()
    }

    func beginAttackWindUp(for combatantID: String) {
        spectacle.nextID += 1
        publishAttackReaction(
            CombatantAttackReaction(id: spectacle.nextID, kind: .attack, phase: .windUp),
            for: combatantID
        )
    }

    func commitAttackSwing(for combatantID: String) {
        spectacle.nextID += 1
        publishAttackReaction(
            CombatantAttackReaction(id: spectacle.nextID, kind: .attack, phase: .swing),
            for: combatantID
        )
    }

    func cancelAttack(for combatantID: String) {
        spectacle.nextID += 1
        publishAttackReaction(
            CombatantAttackReaction(id: spectacle.nextID, kind: .attack, phase: .cancel),
            for: combatantID
        )
    }

    func publishFullAttack(for combatantID: String) {
        spectacle.nextID += 1
        publishAttackReaction(
            CombatantAttackReaction(id: spectacle.nextID, kind: .attack, phase: .full),
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
        guard var cinematic = spectacle.activeCinematic, cinematic.phase == .expanding else { return }
        cinematic.phase = .playing
        spectacle.activeCinematic = cinematic
    }

    func completeCinematicCollapse(expectedID: Int? = nil, at date: Date = .now) {
        guard let cinematic = spectacle.activeCinematic else { return }
        // Ignore stale collapse tasks from a prior cinematic (unstructured sleep can outlive
        // the overlay that started them).
        if let expectedID, cinematic.id != expectedID {
            return
        }
        spectacle.actorsWhoPresentedUltimateThisBattle.insert(cinematic.actorID)
        spectacle.activeCinematic = nil
        spectacle.presentationHoldCount = max(0, spectacle.presentationHoldCount - 1)
        let deferred = spectacle.deferredFeedbackEvents
        if !spectacle.deferredFeedbackEvents.isEmpty {
            spectacle.deferredFeedbackEvents = []
        }
        feedback.record(deferred, at: date, environment: presentationEnvironment)
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
            if spectacle.victorySummary != nil, !spectacle.isShowingVictory {
                scheduleVictoryPresentation(after: date)
                return
            }
        case .defeat:
            if !spectacle.isShowingDefeat {
                scheduleDefeatPresentation(after: date)
                return
            }
        case .none:
            break
        }
        scheduleAutoEndIfNeeded()
    }

    func beginCinematicCollapse(expectedID: Int? = nil) {
        guard var cinematic = spectacle.activeCinematic, cinematic.phase != .collapsing else { return }
        // Ignore stale auto-finish tasks from a prior overlay (fallback hold / video end
        // can outlive the view that scheduled them).
        if let expectedID, cinematic.id != expectedID {
            return
        }
        cinematic.phase = .collapsing
        spectacle.activeCinematic = cinematic
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
                if spectacle.activeCinematic != nil {
                    return nil
                }
                publishPartyCelebrateReactions(at: date)
                return state?.earnedGold ?? 0
            }
            guard let battleState = state else { return nil }
            spectacle.victorySummary = BattleVictorySummary.make(
                configuration: configuration,
                state: battleState,
                homestead: homestead
            )
            // Defer outcome chrome until Ultimate collapse so the killing blow finishes.
            if spectacle.activeCinematic == nil {
                scheduleVictoryPresentation(after: date)
            }
            return nil
        case .defeat:
            if spectacle.activeCinematic == nil {
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
            session.spectacle.isShowingVictory = true
        }
    }

    /// Squish/bounce living Hero + Pet cards while the enemy dissolves.
    /// Lands on the frame after dissolve starts so KeyframeAnimator work does not
    /// share the killing-blow chip/layout commit.
    private func publishPartyCelebrateReactions(at date: Date) {
        spectacle.pendingPartyCelebrateTask?.cancel()
        spectacle.pendingPartyCelebrateTask = nil
        let delay = partyCelebrateDelayOverride ?? 0.032
        if delay <= 0 {
            publishPartyCelebrateReactionsNow(at: date)
            return
        }
        spectacle.pendingPartyCelebrateTask = Task { @MainActor [weak self] in
            // One display period past dissolve start (~16 ms) plus a small settle.
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            publishPartyCelebrateReactionsNow(at: date)
            spectacle.pendingPartyCelebrateTask = nil
        }
    }

    private func publishPartyCelebrateReactionsNow(at date: Date) {
        guard let battleState = state else { return }
        // Negative synthetic IDs stay clear of engine event / feedback item IDs.
        let baseID = -1 * max(1, Int(date.timeIntervalSinceReferenceDate * 1000))
        var didPublish = false
        if battleState.isHeroAlive {
            feedback.hitReactionsByTargetID[battleState.hero.id] = CombatantHitReaction(
                id: baseID,
                kind: .celebrate
            )
            didPublish = true
        }
        if battleState.isCompanionAlive {
            feedback.hitReactionsByTargetID[battleState.companion.id] = CombatantHitReaction(
                id: baseID &- 1,
                kind: .celebrate
            )
            didPublish = true
        }
        if didPublish {
            feedback.noteHitReactionsChanged()
        }
    }

    /// Surfaces victory chrome after a claimed-stage auto-complete persist failure so
    /// the player can retry via Loot All instead of remaining stuck on the battlefield.
    func presentVictoryChromeForPersistRetry(homestead: PlayerHomesteadState) {
        guard outcome == .victory,
              let configuration = activeBattle,
              let battleState = state,
              !spectacle.isShowingVictory
        else { return }
        if spectacle.victorySummary == nil {
            spectacle.victorySummary = BattleVictorySummary.make(
                configuration: configuration,
                state: battleState,
                homestead: homestead
            )
        }
        spectacle.isShowingVictory = true
    }

    #if DEBUG
    func debugSkipCombat(homestead: PlayerHomesteadState) {
        guard let configuration = activeBattle,
              let battleState = state,
              !spectacle.isShowingVictory,
              !spectacle.isShowingDefeat
        else { return }

        cancelPendingAutoEnd()
        cancelOpeningHandDeal()
        spectacle.pendingOutcomePresentationTask?.cancel()
        spectacle.pendingOutcomePresentationTask = nil
        clearSpectacle()
        spectacle.victorySummary = BattleVictorySummary.make(
            configuration: configuration,
            state: battleState,
            homestead: homestead
        )
        spectacle.isShowingVictory = true
        presentationEnvironment.playSFX([SFXID.victory])
    }
    #endif

    func scheduleDefeatPresentation(after date: Date) {
        scheduleOutcomePresentation(
            after: date,
            expected: .defeat,
            sfx: SFXID.defeat
        ) { session in
            session.spectacle.isShowingDefeat = true
        }
    }

    private func scheduleOutcomePresentation(
        after date: Date,
        expected: BattleSimulationOutcome,
        sfx: String,
        show: @escaping @MainActor (BattleSession) -> Void
    ) {
        if spectacle.pendingOutcomePresentationTask != nil, outcome == expected {
            return
        }
        spectacle.pendingOutcomePresentationTask?.cancel()
        let latestFeedbackDelay = feedback.activeItems
            .map { max(0, $0.expiresAt.timeIntervalSince(date)) }
            .max() ?? 0
        let spectacleDelay = max(TrinketMotion.Battle.cardActivationDuration, latestFeedbackDelay)
            + TrinketMotion.Battle.outcomePresentationPadding
        let delay = outcomePresentationDelayOverride ?? spectacleDelay
        guard delay > 0 else {
            show(self)
            presentationEnvironment.playSFX([sfx])
            return
        }
        spectacle.pendingOutcomePresentationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, outcome == expected else { return }
            show(self)
            presentationEnvironment.playSFX([sfx])
            spectacle.pendingOutcomePresentationTask = nil
        }
    }

    func presentResolvedEvents(_ events: [ActionEvent], at date: Date) {
        let nonMilestone = events.filter { $0.kind != .milestone }
        guard let state else {
            feedback.record(nonMilestone, at: date, environment: presentationEnvironment)
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
            let autoSkip = presentationEnvironment.shouldAutoSkipUltimateCinematic(
                ultimate.actorID,
                spectacle.actorsWhoPresentedUltimateThisBattle
            )
            if autoSkip {
                feedback.record(nonMilestone, at: date, environment: presentationEnvironment)
                return
            }
            spectacle.deferredFeedbackEvents = nonMilestone
            beginCinematic(from: ultimate, at: date)
            // Prune may have suppressed its publish; clear expired chips once.
            feedback.noteItemsChanged()
            return
        }

        feedback.record(nonMilestone, at: date, environment: presentationEnvironment)
        presentCallouts(from: nonMilestone, heroID: heroID, companionID: companionID, at: date)
    }

    func beginCinematic(from event: ActionEvent, at date: Date) {
        spectacle.nextID += 1
        spectacle.presentationHoldCount += 1
        spectacle.activeCinematic = BattleCinematicPresentation(
            id: spectacle.nextID,
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
        spectacle.nextID += 1
        let hold = TrinketMotion.Battle.skillSoftHold
        spectacle.softHoldUntil = date.addingTimeInterval(hold)
        spectacle.activeSkillCallout = SkillCalloutPresentation(
            id: spectacle.nextID,
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
        feedback.clear()
        clearSpectacle()
        spectacle.presentationHoldCount = 0
    }

    func clearSpectacle(releaseCinematicPlayers: Bool = true) {
        spectacle.pendingPartyCelebrateTask?.cancel()
        spectacle.pendingPartyCelebrateTask = nil
        if spectacle.activeSkillCallout != nil {
            spectacle.activeSkillCallout = nil
        }
        if spectacle.activeCinematic != nil {
            spectacle.activeCinematic = nil
        }
        spectacle.deferredFeedbackEvents = []
        if spectacle.softHoldUntil != nil {
            spectacle.softHoldUntil = nil
        }
        if !spectacle.actorsWhoPresentedUltimateThisBattle.isEmpty {
            spectacle.actorsWhoPresentedUltimateThisBattle = []
        }
        if releaseCinematicPlayers {
            BattleCinematicPlayer.shared.releaseAll()
        }
    }

    func pruneExpiredSkillCallout(at date: Date) {
        guard let activeSkillCallout = spectacle.activeSkillCallout,
              date >= activeSkillCallout.expiresAt else { return }
        spectacle.activeSkillCallout = nil
    }

    func pruneSoftHold(at date: Date) {
        guard let softHoldUntil = spectacle.softHoldUntil,
              date >= softHoldUntil else { return }
        spectacle.softHoldUntil = nil
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
        feedback.clear()
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
        feedback.clear()
        clearSpectacle()
        clearOutcomePresentation()
        feedback.release()
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
        spectacle.presentationHoldCount = 0
    }
}
