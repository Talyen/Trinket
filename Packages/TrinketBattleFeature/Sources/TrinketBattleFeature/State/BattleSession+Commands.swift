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
        pruneSoftHold(at: date)
        guard spectacle.activeCinematic == nil,
              !spectacle.isShowingVictory,
              !spectacle.isShowingDefeat,
              !isDealingOpeningHand,
              runtime.hasActiveSimulation,
              !runtime.isBattleOver
        else {
            feedback.noteItemsChanged()
            return .rejected
        }

        do {
            let events = try measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardEngine
            ) {
                try runtime.playCard(cardID: cardID)
            }
            guard runtime.hasActiveSimulation, activeBattle?.id != nil else {
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
            let earnedGold = handleOutcomeIfNeeded(at: date)
            if earnedGold == nil {
                scheduleAutoEndIfNeeded()
            }
            return .committed(earnedGold: earnedGold)
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

    @discardableResult
    func endTurn(at date: Date = .now) -> Int? {
        cancelPendingAutoEnd()
        feedback.pruneExpired(at: date, notifyPresentation: false)
        pruneExpiredSkillCallout(at: date)
        pruneSoftHold(at: date)
        guard canEndTurn, runtime.hasActiveSimulation else {
            feedback.noteItemsChanged()
            return nil
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

        let events = runtime.endTurn()
        if runtime.hasActiveSimulation {
            installSimulationPresentation()
            if runtime.phase == .playerTurn {
                presentationEnvironment.playSFX([SFXID.abilityDraw])
            }
        }
        presentResolvedEvents(events, at: date)
        let earnedGold = handleOutcomeIfNeeded(at: date)
        if earnedGold == nil {
            scheduleAutoEndIfNeeded()
        }
        return earnedGold
    }

    func beginOpeningHandDeal(for configurationID: UUID) {
        guard runtime.hasActiveSimulation,
              runtime.hand.isEmpty,
              activeBattle?.id == configurationID
        else { return }

        if openingHandDrawStagger <= 0 {
            _ = runtime.drawOpeningHand()
            installSimulationPresentation()
            presentationEnvironment.playSFX([SFXID.abilityDraw])
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
                      runtime.hasActiveSimulation
                else { return }

                let drew = withAnimation(TrinketMotion.Battle.deal) {
                    let didDraw = runtime.drawNextOpeningHandCard()
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
                  runtime.hasActiveSimulation
            else { return }

            runtime.finalizeOpeningHand()
            installSimulationPresentation()
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

            if shouldTelegraphEnemyAttack(), let enemyID = runtime.enemyID {
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

            let earnedGold = endTurn()
            onTurnAutoEnded?(earnedGold)
        }
    }

    func shouldTelegraphEnemyAttack() -> Bool {
        runtime.shouldTelegraphEnemyAttack()
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
                || !canEndTurn
                || isShowingBattleLog
                || overlayCombatantDetail != nil
                || overlayAbilityDetail != nil
                || isManualInteractionActive()
                || isCardCastActive() {
                await waitForAutoBattleRetry()
                continue
            }

            guard let card = hand.first(where: { isCardPlayable($0) }) else {
                if !hasPendingAutoEnd {
                    scheduleAutoEndIfNeeded()
                }
                await waitForAutoBattleRetry()
                continue
            }

            guard await playCard(card) else { return }
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
