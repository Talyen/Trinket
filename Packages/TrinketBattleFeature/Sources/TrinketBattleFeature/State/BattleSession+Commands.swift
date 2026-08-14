import BattleEngine
import Foundation
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

extension BattleSession {
    @discardableResult
    func playCard(
        cardID: Int,
        at date: Date = .now
    ) -> BattleCardPlayResolution {
        cancelPendingAutoEnd()
        feedback.pruneExpired(at: date, notifyPresentation: false)
        pruneExpiredSkillCallout(at: date)
        guard spectacle.activeCinematic == nil,
              !spectacle.isShowingVictory,
              !spectacle.isShowingDefeat,
              !isDealingOpeningHand,
              hasActiveSimulation,
              !isBattleOver
        else {
            feedback.noteItemsChanged()
            return .rejected
        }

        do {
            let events = try measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardEngine
            ) {
                try playEngineCard(cardID: cardID)
            }
            guard hasActiveSimulation, activeBattle?.id != nil else {
                return .rejected
            }

            measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardProjection
            ) {
                installSimulationPresentation()
            }
            measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardFeedback
            ) {
                presentResolvedEvents(events, at: date)
            }
            handleOutcomeIfNeeded(at: date)
            scheduleAutoEndIfNeeded()
            return .committed
        } catch {
            #if DEBUG
            BattleFramePacingSignposts.event(
                BattleFramePacingSignposts.Name.playCardRejected,
                detail: "cardID=\(cardID)"
            )
            #endif
            feedback.noteItemsChanged()
            return .rejected
        }
    }

    func endTurn(at date: Date = .now) {
        cancelPendingAutoEnd()
        feedback.pruneExpired(at: date, notifyPresentation: false)
        pruneExpiredSkillCallout(at: date)
        guard canEndTurn, hasActiveSimulation else {
            feedback.noteItemsChanged()
            return
        }

        let transitionInterval = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.turnTransition
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.turnTransition,
                transitionInterval
            )
        }

        let events = endEngineTurn()
        if hasActiveSimulation {
            installSimulationPresentation()
            if phase == .playerTurn {
                presentationEnvironment.playSFX([SFXID.abilityDraw])
            }
        }
        presentResolvedEvents(events, at: date)
        handleOutcomeIfNeeded(at: date)
        scheduleAutoEndIfNeeded()
    }

    func beginOpeningHandDeal(for configurationID: UUID) {
        guard hasActiveSimulation,
              engineHand.isEmpty,
              activeBattle?.id == configurationID
        else { return }

        if openingHandDrawStagger <= 0 {
            let events = drawOpeningHand()
            installSimulationPresentation()
            presentationEnvironment.playSFX([SFXID.abilityDraw])
            presentResolvedEvents(events, at: .now)
            scheduleAutoEndIfNeeded()
            return
        }

        openingHandDealGeneration &+= 1
        let generation = openingHandDealGeneration
        isDealingOpeningHand = true
        pendingOpeningHandDealTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.openingHandDealGeneration == generation {
                    self.isDealingOpeningHand = false
                    self.pendingOpeningHandDealTask = nil
                }
            }

            await CombatFeedbackDisplayLinkGate.waitForNextDisplayLink()
            guard !Task.isCancelled,
                  activeBattle?.id == configurationID
            else { return }

            presentationEnvironment.playSFX([SFXID.abilityDraw])

            while true {
                guard !Task.isCancelled,
                      activeBattle?.id == configurationID,
                      hasActiveSimulation
                else { return }

                let drew = withAnimation(TrinketMotion.Battle.deal) {
                    let didDraw = drawNextOpeningHandCard()
                    if didDraw {
                        installSimulationPresentation()
                    }
                    return didDraw
                }
                guard drew else { break }

                let stagger = openingHandDrawStagger
                if stagger > 0 {
                    try? await Task.sleep(for: .seconds(stagger))
                }
            }

            guard !Task.isCancelled,
                  activeBattle?.id == configurationID,
                  hasActiveSimulation
            else { return }

            let events = finalizeOpeningHand()
            installSimulationPresentation()
            presentResolvedEvents(events, at: .now)
            scheduleAutoEndIfNeeded()
        }
    }

    func cancelOpeningHandDeal() {
        openingHandDealGeneration &+= 1
        pendingOpeningHandDealTask?.cancel()
        pendingOpeningHandDealTask = nil
        isDealingOpeningHand = false
    }

    func cancelPendingAutoEnd() {
        pendingAutoEndTask?.cancel()
        pendingAutoEndTask = nil
    }

    func scheduleAutoEndIfNeeded() {
        cancelPendingAutoEnd()
        guard !isSuspendedForScenePhase,
              canEndTurn,
              !hasPlayableCard
        else { return }

        pendingAutoEndTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(autoEndTurnDelay))
            guard !Task.isCancelled,
                  !isSuspendedForScenePhase,
                  canEndTurn,
                  !hasPlayableCard
            else { return }

            if shouldTelegraphEnemyAttack(), let enemyID {
                publishFullAttack(for: enemyID)
                let impactDelay = enemyAttackImpactDelayOverride
                    ?? CombatFeedbackAttackRecipes.cardAttack(for: .attack).impactDelay
                if impactDelay > 0 {
                    try? await Task.sleep(for: .seconds(impactDelay))
                    guard !Task.isCancelled,
                          !isSuspendedForScenePhase,
                          canEndTurn,
                          !hasPlayableCard
                    else { return }
                }
            }

            endTurn()
        }
    }

    func driveAutoBattle(
        isCardCastActive: @escaping @MainActor () -> Bool,
        isManualInteractionActive: @escaping @MainActor () -> Bool,
        playCard: @escaping @MainActor (BattleCard) async -> Bool
    ) async {
        while !Task.isCancelled, isAutoBattleEnabled {
            guard activeBattle != nil,
                  outcome == nil
            else { return }

            if isSuspendedForScenePhase
                || isDealingOpeningHand
                || !canEndTurn
                || isShowingBattleLog
                || overlayCombatantDetail != nil
                || overlayAbilityDetail != nil
                || isManualInteractionActive()
                || isCardCastActive() {
                await waitForAutoBattleRetry()
                continue
            }

            guard let engineState,
                  let card = GreedyHeuristicPolicy().preferredPlayableCard(in: engineState)
            else {
                if !hasPendingAutoEnd {
                    scheduleAutoEndIfNeeded()
                }
                await waitForAutoBattleRetry()
                continue
            }

            guard await playCard(card) else {
                await waitForAutoBattleRetry()
                continue
            }
            guard !Task.isCancelled, isAutoBattleEnabled, outcome == nil else { return }

            while !Task.isCancelled, isAutoBattleEnabled, isCardCastActive() {
                await waitForAutoBattleRetry()
            }
        }
    }

    private func waitForAutoBattleRetry() async {
        if autoBattleRetryDelay > .zero {
            try? await Task.sleep(for: autoBattleRetryDelay)
        } else {
            await Task.yield()
        }
    }

    private func measurePlayCardInterval<Result>(
        _ name: StaticString,
        _ operation: () throws -> Result
    ) rethrows -> Result {
        let interval = BattleFramePacingSignposts.signposter.beginInterval(name)
        defer {
            BattleFramePacingSignposts.signposter.endInterval(name, interval)
        }
        return try operation()
    }
}
