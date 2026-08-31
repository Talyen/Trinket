import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

extension BattleSession {
    public func presentCombatantDetail(_ detail: CombatantCardDetail) {
        overlayCombatantDetail = detail
    }

    public func presentAbilityDetail(_ ability: Ability) {
        overlayAbilityDetail = ability
    }

    func publishAttackReaction(_ reaction: CombatantAttackReaction, for combatantID: String) {
        feedback.attackReactionsByCombatantID[combatantID] = reaction
        feedback.noteAttackReactionsChanged(for: combatantID)
    }

    func publishAttackTelegraph(
        _ phase: CombatantAttackPhase,
        for combatantID: String,
    ) {
        spectacle.nextID += 1
        publishAttackReaction(
            CombatantAttackReaction(id: spectacle.nextID, kind: .attack, phase: phase),
            for: combatantID,
        )
    }

    func combatantID(for participant: BattleParticipant) -> String? {
        switch participant {
        case .hero:
            presentation.hero?.combatant.id ?? heroID
        case .companion:
            presentation.companion?.combatant.id ?? companionID
        case .enemy:
            presentation.enemy?.combatant.id ?? enemyID
        }
    }

    func clearUltimateHighlight(for actorID: String) {
        spectacle.pendingUltimateHighlightTasksByActorID[actorID]?.cancel()
        spectacle.pendingUltimateHighlightTasksByActorID[actorID] = nil
        spectacle.ultimateHighlightsByActorID[actorID] = nil
        BattleCinematicPlayer.shared.pause(actorID: actorID, abilityID: "")
    }

    func handleOutcomeIfNeeded(at date: Date) {
        guard let configuration = activeBattle,
              let context = presentationContext
        else { return }
        switch outcome {
        case .victory:
            if context.stageRewardsAlreadyClaimed {
                publishPartyCelebrateReactions(at: date)
                deliverClaimedVictoryIfNeeded()
                return
            }
            guard let summary = makeVictorySummary(for: configuration, presentation: context) else { return }
            spectacle.victorySummary = summary
            scheduleVictoryPresentation(after: date)
        case .defeat:
            scheduleDefeatPresentation(after: date)
        case .none:
            break
        }
    }

    func scheduleVictoryPresentation(after date: Date) {
        publishPartyCelebrateReactions(at: date)
        scheduleOutcomePresentation(
            after: date,
            expected: .victory,
            sfx: SFXID.victory,
        ) { session in
            session.spectacle.isShowingVictory = true
        }
    }

    func publishPartyCelebrateReactions(at date: Date) {
        spectacle.pendingPartyCelebrateTask?.cancel()
        spectacle.pendingPartyCelebrateTask = nil
        let delay = partyCelebrateDelayOverride ?? .seconds(0.032)
        if delay <= .zero {
            publishPartyCelebrateReactionsNow(at: date)
            return
        }
        spectacle.pendingPartyCelebrateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            publishPartyCelebrateReactionsNow(at: date)
            spectacle.pendingPartyCelebrateTask = nil
        }
    }

    private func publishPartyCelebrateReactionsNow(at date: Date) {
        guard let heroID,
              let companionID
        else { return }
        let baseID = -1 * max(1, Int(date.timeIntervalSinceReferenceDate * 1000))
        var didPublish = false
        if isHeroAlive {
            feedback.hitReactionsByTargetID[heroID] = CombatantHitReaction(
                id: baseID,
                kind: .celebrate,
            )
            didPublish = true
        }
        if isCompanionAlive {
            feedback.hitReactionsByTargetID[companionID] = CombatantHitReaction(
                id: baseID &- 1,
                kind: .celebrate,
            )
            didPublish = true
        }
        if didPublish {
            var reactedIDs: Set<String> = []
            if isHeroAlive {
                reactedIDs.insert(heroID)
            }
            if isCompanionAlive {
                reactedIDs.insert(companionID)
            }
            feedback.noteHitReactionsChanged(for: reactedIDs)
        }
    }

    public func presentVictoryChromeForPersistRetry() {
        guard outcome == .victory,
              let configuration = activeBattle,
              let context = presentationContext,
              hasActiveSimulation,
              !spectacle.isShowingVictory
        else { return }
        if spectacle.victorySummary == nil {
            spectacle.victorySummary = makeVictorySummary(for: configuration, presentation: context)
        }
        spectacle.isShowingVictory = true
    }

    #if DEBUG
    func debugSkipCombat() {
        guard let configuration = activeBattle,
              let context = presentationContext,
              hasActiveSimulation,
              !spectacle.isShowingVictory,
              !spectacle.isShowingDefeat
        else { return }

        cancelPendingAutoEnd()
        cancelOpeningHandDeal()
        spectacle.pendingOutcomePresentationTask?.cancel()
        spectacle.pendingOutcomePresentationTask = nil
        clearSpectacle()
        spectacle.victorySummary = makeVictorySummary(for: configuration, presentation: context)
        spectacle.isShowingVictory = true
        presentationEnvironment.playSFX([SFXID.victory])
    }
    #endif

    func scheduleDefeatPresentation(after date: Date) {
        scheduleOutcomePresentation(
            after: date,
            expected: .defeat,
            sfx: SFXID.defeat,
        ) { session in
            session.spectacle.isShowingDefeat = true
        }
    }

    private func scheduleOutcomePresentation(
        after date: Date,
        expected: BattleSimulationOutcome,
        sfx: String,
        show: @escaping @MainActor (BattleSession) -> Void,
    ) {
        if spectacle.pendingOutcomePresentationTask != nil, outcome == expected {
            return
        }
        spectacle.pendingOutcomePresentationTask?.cancel()
        let latestFeedbackDelay = feedback.activeItems
            .map { max(0, $0.expiresAt.timeIntervalSince(date)) }
            .max() ?? 0
        let spectacleDelaySeconds = max(BattleMotion.outcomePresentationMinimum, latestFeedbackDelay)
            + BattleMotion.outcomePresentationPadding
        let spectacleDelay = Duration.seconds(spectacleDelaySeconds)
        let delay = outcomePresentationDelayOverride ?? spectacleDelay
        guard delay > .zero else {
            show(self)
            presentationEnvironment.playSFX([sfx])
            return
        }
        spectacle.pendingOutcomePresentationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled, outcome == expected else { return }
            show(self)
            presentationEnvironment.playSFX([sfx])
            spectacle.pendingOutcomePresentationTask = nil
        }
    }

    func presentResolvedEvents(_ events: [ActionEvent], at date: Date) {
        let nonMilestone = events.filter { $0.kind != .milestone }
        feedback.record(nonMilestone, at: date, environment: presentationEnvironment)
        guard let heroID,
              let companionID
        else { return }
        if let ultimate = nonMilestone.first(where: {
            BattleSpectaclePolicy.shouldPresentUltimateHighlight(
                for: $0,
                heroID: heroID,
                companionID: companionID,
            )
        }) {
            triggerUltimateInFrameHighlight(from: ultimate, at: date)
        }
    }

    func triggerUltimateInFrameHighlight(from event: ActionEvent, at date: Date) {
        let autoSkip = presentationEnvironment.shouldAutoSkipUltimateCinematic(
            event.actorID,
            spectacle.actorsWhoPresentedUltimateThisBattle,
        )
        if autoSkip {
            return
        }
        spectacle.actorsWhoPresentedUltimateThisBattle.insert(event.actorID)
        spectacle.nextID += 1
        let highlightID = spectacle.nextID
        let highlight = BattleUltimateInFramePresentation(
            id: highlightID,
            actorID: event.actorID,
            actorName: event.actorName,
            abilityID: event.abilityID,
            abilityName: event.abilityName,
            keyword: event.keyword,
            startedAt: date,
        )
        spectacle.pendingUltimateHighlightTasksByActorID[event.actorID]?.cancel()
        spectacle.ultimateHighlightsByActorID[event.actorID] = highlight
        BattleCinematicPlayer.shared.warm(actorID: event.actorID, abilityID: event.abilityID)
        let hold = BattleMotion.ultimateInFrameDuration
        spectacle.pendingUltimateHighlightTasksByActorID[event.actorID] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(hold))
            guard let self, !Task.isCancelled else { return }
            if spectacle.ultimateHighlightsByActorID[event.actorID]?.id == highlightID {
                spectacle.ultimateHighlightsByActorID[event.actorID] = nil
            }
            spectacle.pendingUltimateHighlightTasksByActorID[event.actorID] = nil
        }
    }

    func cancelUltimateHighlightWatchdogs() {
        for task in spectacle.pendingUltimateHighlightTasksByActorID.values {
            task.cancel()
        }
        spectacle.pendingUltimateHighlightTasksByActorID.removeAll()
    }

    func clearAllPresentation() {
        clearOutcomePresentation()
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
        feedback.clear()
        clearSpectacle()
    }

    func clearSpectacle(releaseCinematicPlayers: Bool = true) {
        spectacle.pendingPartyCelebrateTask?.cancel()
        spectacle.pendingPartyCelebrateTask = nil
        cancelUltimateHighlightWatchdogs()
        if !spectacle.ultimateHighlightsByActorID.isEmpty {
            spectacle.ultimateHighlightsByActorID = [:]
        }
        if !spectacle.actorsWhoPresentedUltimateThisBattle.isEmpty {
            spectacle.actorsWhoPresentedUltimateThisBattle = []
        }
        if releaseCinematicPlayers {
            BattleCinematicPlayer.shared.releaseAll()
        }
    }

    func resetRun(
        from configuration: BattleRunConfiguration,
        holdOpeningHandForOverlayFade: Bool = false,
    ) {
        cancelPendingAutoEnd()
        cancelPendingEnemyTurnReset()
        isEnemyTurnActive = false
        cancelOpeningHandDeal()
        deliveredClaimedVictoryConfigurationID = nil
        installSimulationPresentation()
        feedback.clear()
        resetFeedbackRasterDiagnostics()
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
        let preferred = Self.preferredAutoBattleEnabled(from: presentationEnvironment)
        if isAutoBattleEnabled != preferred {
            isAutoBattleEnabled = preferred
        }
        beginOpeningHandDeal(
            for: configuration.id,
            startDelay: holdOpeningHandForOverlayFade
                ? .seconds(TrinketMotion.Screen.crossfadeDuration)
                : .zero,
        )
    }

    func clearRunState() {
        cancelPendingAutoEnd()
        cancelPendingEnemyTurnReset()
        isEnemyTurnActive = false
        cancelOpeningHandDeal()
        deliveredClaimedVictoryConfigurationID = nil
        presentation.clear()
        feedback.clear()
        resetFeedbackRasterDiagnostics()
        clearSpectacle()
        clearOutcomePresentation()
        feedback.release()
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
        presentationContext = nil
    }
}
