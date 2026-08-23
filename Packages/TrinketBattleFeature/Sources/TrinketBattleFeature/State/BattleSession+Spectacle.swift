import BattleEngine
import Foundation
import TrinketBattleRuntime
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
            presentation.hero?.combatant.id ?? heroID
        case .companion:
            presentation.companion?.combatant.id ?? companionID
        case .enemy:
            presentation.enemy?.combatant.id ?? enemyID
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
        cancelCinematicWatchdog()
        BattleCinematicPlayer.shared.pause(
            actorID: cinematic.actorID,
            abilityID: cinematic.abilityID
        )
        spectacle.actorsWhoPresentedUltimateThisBattle.insert(cinematic.actorID)
        spectacle.activeCinematic = nil
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
            if presentationContext?.stageRewardsAlreadyClaimed == true {
                publishPartyCelebrateReactions(at: date)
                deliverClaimedVictoryIfNeeded()
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

    func handleOutcomeIfNeeded(at date: Date) {
        guard let configuration = activeBattle,
              let context = presentationContext
        else { return }
        switch outcome {
        case .victory:
            if context.stageRewardsAlreadyClaimed {
                // Keep the Ultimate on screen; collapse fires claimed-stage auto-complete.
                if spectacle.activeCinematic != nil {
                    return
                }
                publishPartyCelebrateReactions(at: date)
                deliverClaimedVictoryIfNeeded()
                return
            }
            guard let summary = makeVictorySummary(for: configuration, presentation: context) else { return }
            spectacle.victorySummary = summary
            // Defer outcome chrome until Ultimate collapse so the killing blow finishes.
            if spectacle.activeCinematic == nil {
                scheduleVictoryPresentation(after: date)
            }
        case .defeat:
            if spectacle.activeCinematic == nil {
                scheduleDefeatPresentation(after: date)
            }
        case .none:
            break
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
    func publishPartyCelebrateReactions(at date: Date) {
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
        guard let heroID,
              let companionID
        else { return }
        // Negative synthetic IDs stay clear of engine event / feedback item IDs.
        let baseID = -1 * max(1, Int(date.timeIntervalSinceReferenceDate * 1000))
        var didPublish = false
        if isHeroAlive {
            feedback.hitReactionsByTargetID[heroID] = CombatantHitReaction(
                id: baseID,
                kind: .celebrate
            )
            didPublish = true
        }
        if isCompanionAlive {
            feedback.hitReactionsByTargetID[companionID] = CombatantHitReaction(
                id: baseID &- 1,
                kind: .celebrate
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

    /// Surfaces victory chrome after a claimed-stage auto-complete persist failure so
    /// the player can retry via Loot All instead of remaining stuck on the battlefield.
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
        let spectacleDelay = max(TrinketMotion.Battle.outcomePresentationMinimum, latestFeedbackDelay)
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
        guard let heroID,
              let companionID
        else {
            feedback.record(nonMilestone, at: date, environment: presentationEnvironment)
            return
        }

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
            let hasVideo = BattleCinematicPlayer.shared.hasVideo(
                for: ultimate.actorID,
                abilityID: ultimate.abilityID
            )
            // Unmapped casts skip the overlay entirely — never full-screen ability art.
            if autoSkip || !hasVideo {
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
    }

    func beginCinematic(from event: ActionEvent, at date: Date) {
        spectacle.nextID += 1
        let cinematicID = spectacle.nextID
        spectacle.activeCinematic = BattleCinematicPresentation(
            id: cinematicID,
            actorID: event.actorID,
            actorName: event.actorName,
            abilityID: event.abilityID,
            abilityName: event.abilityName,
            keyword: event.keyword,
            phase: .expanding,
            startedAt: date
        )
        BattleCinematicPlayer.shared.warm(actorID: event.actorID, abilityID: event.abilityID)
        scheduleCinematicWatchdog(expectedID: cinematicID)
    }

    func scheduleCinematicWatchdog(expectedID: Int) {
        cancelCinematicWatchdog()
        let hold = cinematicSessionWatchdogOverride
            ?? TrinketMotion.Battle.ultimateCinematicSessionWatchdog
        spectacle.pendingCinematicWatchdogTask = Task { @MainActor [weak self] in
            if hold > 0 {
                try? await Task.sleep(for: .seconds(hold))
            }
            guard let self, !Task.isCancelled else { return }
            completeCinematicCollapse(expectedID: expectedID)
        }
    }

    func cancelCinematicWatchdog() {
        spectacle.pendingCinematicWatchdogTask?.cancel()
        spectacle.pendingCinematicWatchdogTask = nil
    }

    func clearAllPresentation() {
        clearOutcomePresentation()
        overlayCombatantDetail = nil
        overlayAbilityDetail = nil
        pendingBranchChoice = nil
        isShowingBattleLog = false
        feedback.clear()
        clearSpectacle()
    }

    func clearSpectacle(releaseCinematicPlayers: Bool = true) {
        spectacle.pendingPartyCelebrateTask?.cancel()
        spectacle.pendingPartyCelebrateTask = nil
        cancelCinematicWatchdog()
        if spectacle.activeCinematic != nil {
            spectacle.activeCinematic = nil
        }
        spectacle.deferredFeedbackEvents = []
        if !spectacle.actorsWhoPresentedUltimateThisBattle.isEmpty {
            spectacle.actorsWhoPresentedUltimateThisBattle = []
        }
        if releaseCinematicPlayers {
            BattleCinematicPlayer.shared.releaseAll()
        }
    }

    func resetRun(from configuration: BattleRunConfiguration) {
        cancelPendingAutoEnd()
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
        if pendingBranchChoice != nil {
            pendingBranchChoice = nil
        }
        if isShowingBattleLog {
            isShowingBattleLog = false
        }
        let preferred = Self.preferredAutoBattleEnabled(from: presentationEnvironment)
        if isAutoBattleEnabled != preferred {
            isAutoBattleEnabled = preferred
        }
        beginOpeningHandDeal(for: configuration.id)
    }

    func clearRunState() {
        cancelPendingAutoEnd()
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
        pendingBranchChoice = nil
        isShowingBattleLog = false
        presentationContext = nil
    }
}
