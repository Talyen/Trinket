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
        feedback.previewAttack(phase, for: combatantID)
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

    func handleOutcomeIfNeeded(at date: Date) {
        guard commandState.phase != .outcome, let configuration = activeBattle,
              let context = presentationContext
        else { return }
        if isInstallingBattle, hasConnectedProgression, outcome != nil {
            // Opening traits resolve synchronously; AppState publishes the active
            // registration only after installation returns successfully.
            Task { @MainActor [weak self] in
                guard let self, activeBattle?.id == configuration.id else { return }
                handleOutcomeIfNeeded(at: date)
            }
            return
        }
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
            session.presentVictory(summary)
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
        let celebrateExpiry = date.addingTimeInterval(BattleMotion.chipDisplayDuration)
        var reactedIDs: Set<String> = []
        for (combatantID, isAlive) in [(heroID, isHeroAlive), (companionID, isCompanionAlive)] where isAlive {
            spectacle.nextID += 1
            feedback.hitReactionsByTargetID[combatantID] = CombatantHitReaction(
                id: -spectacle.nextID,
                kind: .celebrate,
            )
            feedback.celebrateReactionExpiresAt[combatantID] = celebrateExpiry
            reactedIDs.insert(combatantID)
        }
        if !reactedIDs.isEmpty {
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
            presentVictory(summary)
        case .battle, .defeat:
            guard let summary = makeVictorySummary(for: configuration, presentation: context) else { return }
            presentVictory(summary)
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
        presentVictory(summary)
        dependencies.playSFX([SFXID.victory])
    }
    #endif

    func scheduleDefeatPresentation(after date: Date) {
        scheduleOutcomePresentation(
            after: date,
            expected: .defeat,
            sfx: SFXID.defeat,
        ) { session in
            guard let configuration = session.activeBattle else { return }
            guard let settlement = session.makeDefeatSettlement(for: configuration) else { return }
            session.spectacle.outcomePresentation = .defeat(settlement)
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
        let pendingFeedbackDelay = max(0, feedback.pendingFeedbackEnd?.timeIntervalSince(date) ?? 0)
        let spectacleDelaySeconds = max(BattleMotion.outcomePresentationMinimum, latestFeedbackDelay, pendingFeedbackDelay)
            + BattleMotion.outcomePresentationPadding
        let spectacleDelay = Duration.seconds(spectacleDelaySeconds)
        let delay = outcomePresentationDelayOverride ?? spectacleDelay
        guard delay > .zero else {
            show(self)
            dependencies.playSFX([sfx])
            return
        }
        spectacle.outcomeTask.task = Task { @MainActor [weak self] in
            guard let self else { return }
            var remaining = delay
            let clock = ContinuousClock()
            while remaining > .zero, !Task.isCancelled {
                let started = clock.now
                let wasSuspended = isSuspendedForScenePhase
                // Suspension freezes the countdown, so sleep longer while
                // suspended instead of waking every 50 ms for no progress.
                try? await Task.sleep(for: min(remaining, wasSuspended ? .milliseconds(250) : .milliseconds(50)))
                if !wasSuspended, !isSuspendedForScenePhase {
                    remaining -= started.duration(to: clock.now)
                }
            }
            guard !Task.isCancelled, outcome == expected else { return }
            show(self)
            dependencies.playSFX([sfx])
            spectacle.outcomeTask.task = nil
        }
    }

    func clearAllPresentation() {
        resetPresentation(resetSpectacleState: false)
    }

    func clearSpectacle() {
        spectacle.celebrateTask.invalidate()
    }

    func resetRun(from configuration: BattleRunConfiguration) {
        cancelPendingBattleTasks()
        retreatProgress = nil
        deliveredClaimedVictoryConfigurationID = nil
        installSimulationPresentation()
        resetPresentation(resetSpectacleState: false)
        let preferred = Self.preferredAutoBattleEnabled(from: dependencies)
        if isAutoBattleEnabled != preferred {
            isAutoBattleEnabled = preferred
        }
        beginOpeningHandDeal(for: configuration.id)
    }

    func clearRunState() {
        clearCardCues()
        cancelPendingBattleTasks()
        retreatProgress = nil
        deliveredClaimedVictoryConfigurationID = nil
        presentation = BattlePresentationState()
        resetPresentation(resetSpectacleState: true)
        feedback.release()
        presentationContext = nil
    }

    private func resetPresentation(resetSpectacleState: Bool) {
        feedback.clear()
        resetFeedbackRasterDiagnostics()
        if resetSpectacleState {
            spectacle.outcomeTask.invalidate()
            spectacle.celebrateTask.invalidate()
            spectacle = BattleSpectacleState()
            // NB: no unconditional chip-bridge reset here. The lane already
            // publishes `.reset` on clear when it published presentation, and
            // production owns one long-lived session, so a teardown-time
            // unconditional publish would only couple concurrent lanes
            // (tests, DEBUG transition lab) through shared bridge statics.
        } else {
            clearSpectacle()
        }
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
