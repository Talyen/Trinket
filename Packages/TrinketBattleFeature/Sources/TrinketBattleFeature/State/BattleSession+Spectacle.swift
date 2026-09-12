import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

extension BattleSession {
    public func presentCombatantDetail(_ detail: CombatantCardDetail) {
        clearCardCues()
        overlayCombatantDetail = detail
    }

    public func presentAbilityDetail(_ ability: Ability) {
        clearCardCues()
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
        if let highlight = spectacle.ultimateHighlightsByActorID.removeValue(forKey: actorID) {
            spectacle.cinematics.pause(actorID: actorID, abilityID: highlight.abilityID)
        }
    }

    func handleOutcomeIfNeeded(at date: Date) {
        guard commandState.phase != .outcome, let configuration = activeBattle,
              let context = presentationContext
        else { return }
        switch outcome {
        case .victory:
            commandState.transition(to: .outcome)
            clearCardCues()
            if context.stageRewardsAlreadyClaimed {
                publishPartyCelebrateReactions(at: date)
                deliverClaimedVictoryIfNeeded()
                return
            }
            guard let summary = makeVictorySummary(for: configuration, presentation: context) else { return }
            spectacle.outcomePresentation = .pendingVictory(summary)
            scheduleVictoryPresentation(after: date)
        case .defeat:
            commandState.transition(to: .outcome)
            clearCardCues()
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
            guard case let .pendingVictory(summary) = session.spectacle.outcomePresentation else { return }
            session.spectacle.outcomePresentation = .victory(summary)
        }
    }

    func publishPartyCelebrateReactions(at date: Date) {
        spectacle.celebrateTask.invalidate()
        let delay = partyCelebrateDelayOverride ?? .seconds(0.032)
        if delay <= .zero {
            publishPartyCelebrateReactionsNow(at: date)
            return
        }
        spectacle.celebrateTask.task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            publishPartyCelebrateReactionsNow(at: date)
            spectacle.celebrateTask.task = nil
        }
    }

    private func publishPartyCelebrateReactionsNow(at date: Date) {
        guard let heroID,
              let companionID
        else { return }
        spectacle.nextID += 1
        let heroCelebrateID = -spectacle.nextID
        spectacle.nextID += 1
        let companionCelebrateID = -spectacle.nextID
        let celebrateExpiry = date.addingTimeInterval(BattleMotion.chipDisplayDuration)
        var didPublish = false
        if isHeroAlive {
            feedback.hitReactionsByTargetID[heroID] = CombatantHitReaction(
                id: heroCelebrateID,
                kind: .celebrate,
            )
            feedback.celebrateReactionExpiresAt[heroID] = celebrateExpiry
            didPublish = true
        }
        if isCompanionAlive {
            feedback.hitReactionsByTargetID[companionID] = CombatantHitReaction(
                id: companionCelebrateID,
                kind: .celebrate,
            )
            feedback.celebrateReactionExpiresAt[companionID] = celebrateExpiry
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
            feedback.updatePruneDate()
        }
    }

    public func presentVictoryChromeForPersistRetry() {
        guard outcome == .victory,
              let configuration = activeBattle,
              let context = presentationContext,
              hasActiveSimulation
        else { return }
        switch spectacle.outcomePresentation {
        case .victory:
            return
        case let .pendingVictory(summary):
            spectacle.outcomePresentation = .victory(summary)
        case .battle, .defeat:
            guard let summary = makeVictorySummary(for: configuration, presentation: context) else { return }
            spectacle.outcomePresentation = .victory(summary)
        }
    }

    #if DEBUG
    func debugSkipCombat() {
        guard let configuration = activeBattle,
              let context = presentationContext,
              hasActiveSimulation,
              spectacle.outcomePresentation == .battle
        else { return }

        cancelPendingAutoEnd()
        cancelTransitionPresentation()
        spectacle.outcomeTask.invalidate()
        clearSpectacle()
        guard let summary = makeVictorySummary(for: configuration, presentation: context) else { return }
        spectacle.outcomePresentation = .victory(summary)
        dependencies.playSFX([SFXID.victory])
    }
    #endif

    func scheduleDefeatPresentation(after date: Date) {
        scheduleOutcomePresentation(
            after: date,
            expected: .defeat,
            sfx: SFXID.defeat,
        ) { session in
            session.spectacle.outcomePresentation = .defeat
        }
    }

    private func scheduleOutcomePresentation(
        after date: Date,
        expected: BattleSimulationOutcome,
        sfx: String,
        show: @escaping @MainActor (BattleSession) -> Void,
    ) {
        spectacle.outcomeTask.invalidate()
        let latestFeedbackDelay = feedback.activeItems
            .map { max(0, $0.expiresAt.timeIntervalSince(date)) }
            .max() ?? 0
        let spectacleDelaySeconds = max(BattleMotion.outcomePresentationMinimum, latestFeedbackDelay)
            + BattleMotion.outcomePresentationPadding
        let spectacleDelay = Duration.seconds(spectacleDelaySeconds)
        let delay = outcomePresentationDelayOverride ?? spectacleDelay
        guard delay > .zero else {
            show(self)
            dependencies.playSFX([sfx])
            return
        }
        spectacle.outcomeTask.task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled, outcome == expected else { return }
            show(self)
            dependencies.playSFX([sfx])
            spectacle.outcomeTask.task = nil
        }
    }

    func presentResolvedEvents(_ events: [ActionEvent], at date: Date) {
        let nonMilestone = events.filter { $0.kind != .milestone }
        feedback.record(nonMilestone, at: date, environment: dependencies)
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
        spectacle.cinematics.isEnabled = areUltimateCinematicAnimationsEnabled
        guard areUltimateCinematicAnimationsEnabled else { return }
        let autoSkip = dependencies.shouldAutoSkipUltimateCinematic(
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
        spectacle.cinematics.warm(actorID: event.actorID, abilityID: event.abilityID)
        let hold = ultimateInFrameDurationOverride ?? .seconds(BattleMotion.ultimateInFrameDuration)
        spectacle.pendingUltimateHighlightTasksByActorID[event.actorID] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: hold)
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
        resetEphemeralOverlays()
        feedback.clear()
        clearSpectacle()
    }

    func clearSpectacle(releaseCinematicPlayers: Bool = true) {
        spectacle.celebrateTask.invalidate()
        cancelUltimateHighlightWatchdogs()
        if !spectacle.ultimateHighlightsByActorID.isEmpty {
            spectacle.ultimateHighlightsByActorID = [:]
        }
        if !spectacle.actorsWhoPresentedUltimateThisBattle.isEmpty {
            spectacle.actorsWhoPresentedUltimateThisBattle = []
        }
        if releaseCinematicPlayers {
            spectacle.cinematics.releaseAll()
        }
    }

    func resetRun(from configuration: BattleRunConfiguration) {
        cancelPendingBattleTasks()
        deliveredClaimedVictoryConfigurationID = nil
        completionError = nil
        installSimulationPresentation()
        clearSharedPresentation(releaseCinematicPlayers: false)
        let preferred = Self.preferredAutoBattleEnabled(from: dependencies)
        if isAutoBattleEnabled != preferred {
            isAutoBattleEnabled = preferred
        }
        beginOpeningHandDeal(for: configuration.id)
    }

    func clearRunState() {
        clearCardCues()
        cancelPendingBattleTasks()
        deliveredClaimedVictoryConfigurationID = nil
        completionError = nil
        presentation = BattlePresentationState()
        spectacle.outcomeTask.invalidate()
        spectacle.celebrateTask.invalidate()
        cancelUltimateHighlightWatchdogs()
        spectacle = BattleSpectacleState()
        clearSharedPresentation(releaseCinematicPlayers: true)
        feedback.release()
        CombatFeedbackGlyphAtlas.shared.removeAll()
        CardDissolveTexture.clearCache()
        presentationContext = nil
    }

    private func clearSharedPresentation(releaseCinematicPlayers: Bool) {
        feedback.clear()
        resetFeedbackRasterDiagnostics()
        clearSpectacle(releaseCinematicPlayers: releaseCinematicPlayers)
        clearOutcomePresentation()
        resetEphemeralOverlays()
    }

    private func cancelPendingBattleTasks() {
        cancelPendingAutoEnd()
        cancelTransitionPresentation()
    }

    private func resetEphemeralOverlays() {
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        isShowingBattleLog = false
    }
}
