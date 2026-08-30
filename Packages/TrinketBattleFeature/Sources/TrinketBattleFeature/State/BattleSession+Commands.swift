import BattleEngine
import Foundation
import os
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

extension BattleSession {
    private static let commandLogger = Logger(
        subsystem: "com.trinket.battle",
        category: "BattleSession",
    )

    @discardableResult
    func playCard(
        cardID: Int,
        at date: Date = .now,
    ) -> BattleCardPlayResolution {
        cancelPendingAutoEnd()
        feedback.pruneExpired(at: date, notifyPresentation: false)
        guard spectacle.activeCinematic == nil,
              !spectacle.isShowingVictory,
              !spectacle.isShowingDefeat,
              !isDealingOpeningHand,
              hasActiveSimulation,
              !isBattleOver,
              !isSuspendedForScenePhase
        else {
            feedback.noteItemsChanged()
            return .rejected
        }

        do {
            let events = try measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardEngine,
            ) {
                try playEngineCard(cardID: cardID)
            }
            guard hasActiveSimulation, activeBattle?.id != nil else {
                return .rejected
            }

            measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardProjection,
            ) {
                installSimulationPresentation()
            }
            measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardFeedback,
            ) {
                presentResolvedEvents(events, at: date)
            }
            handleOutcomeIfNeeded(at: date)
            scheduleAutoEndIfNeeded()
            return .committed
        } catch BattlePlayError.boonChoicePending {
            feedback.noteItemsChanged()
            return .rejected
        } catch {
            Self.commandLogger.error(
                "playCard failed for card \(cardID, privacy: .public): \(error.localizedDescription, privacy: .public)",
            )
            BattleFramePacingSignposts.event(
                BattleFramePacingSignposts.Name.playCardRejected,
                detail: "cardID=\(cardID)",
            )
            feedback.noteItemsChanged()
            return .rejected
        }
    }

    func endTurn(at date: Date = .now) {
        cancelPendingAutoEnd()
        feedback.pruneExpired(at: date, notifyPresentation: false)
        guard canEndTurn, hasActiveSimulation, !isSuspendedForScenePhase else {
            feedback.noteItemsChanged()
            return
        }

        let transitionInterval = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.turnTransition,
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.turnTransition,
                transitionInterval,
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

    func beginOpeningHandDeal(
        for configurationID: UUID,
        startDelay: Duration = .zero,
    ) {
        guard hasActiveSimulation,
              engineHand.isEmpty,
              activeBattle?.id == configurationID
        else { return }

        if openingHandDrawStagger <= .zero {
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

            guard await waitForOpeningHandDealStart(
                configurationID: configurationID,
                startDelay: startDelay,
            ) else { return }

            presentationEnvironment.playSFX([SFXID.abilityDraw])

            while true {
                guard !Task.isCancelled,
                      activeBattle?.id == configurationID,
                      hasActiveSimulation
                else { return }

                let drew = withAnimation(BattleMotion.deal) {
                    let didDraw = drawNextOpeningHandCard()
                    if didDraw {
                        installSimulationPresentation()
                    }
                    return didDraw
                }
                guard drew else { break }

                let stagger = openingHandDrawStagger
                if stagger > .zero {
                    try? await Task.sleep(for: stagger)
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

    private func waitForOpeningHandDealStart(
        configurationID: UUID,
        startDelay: Duration,
    ) async -> Bool {
        if startDelay > .zero {
            try? await Task.sleep(for: startDelay)
            guard !Task.isCancelled, activeBattle?.id == configurationID else { return false }
        }
        await CombatFeedbackDisplayLinkGate.waitForNextDisplayLink()
        return !Task.isCancelled && activeBattle?.id == configurationID
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
            try? await Task.sleep(for: autoEndTurnDelay)
            guard !Task.isCancelled,
                  !isSuspendedForScenePhase,
                  canEndTurn,
                  !hasPlayableCard
            else { return }

            if shouldTelegraphEnemyAttack(), let enemyID {
                publishAttackTelegraph(.full, for: enemyID)
                let impactDelay = enemyAttackImpactDelayOverride
                    ?? .seconds(CombatFeedbackAttackRecipes.cardAttack(for: .attack).impactDelay)
                if impactDelay > .zero {
                    try? await Task.sleep(for: impactDelay)
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
        playCard: @escaping @MainActor (BattleCard) async -> Bool,
    ) async {
        let autoBattlePolicy = PlayPolicy.greedy
        while !Task.isCancelled, isAutoBattleEnabled {
            guard activeBattle != nil, outcome == nil else { return }

            if pendingBoonOffer != nil {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled, isAutoBattleEnabled else { return }
                _ = selectAutoBoon()
                continue
            }

            if isAutoBattlePresentationBlocked {
                await waitForAutoBattleRetry()
                continue
            }

            await waitWhileAutoBattleBlocked(isBlocked: isManualInteractionActive)
            await waitWhileAutoBattleBlocked(isBlocked: isCardCastActive)
            guard !Task.isCancelled, isAutoBattleEnabled, activeBattle != nil, outcome == nil else {
                return
            }
            if isAutoBattlePresentationBlocked {
                continue
            }

            guard let engineState,
                  let card = autoBattlePolicy.preferredPlayableCard(in: engineState)
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

            await waitWhileAutoBattleBlocked(isBlocked: isCardCastActive)
        }
    }

    private var isAutoBattlePresentationBlocked: Bool {
        isSuspendedForScenePhase
            || isDealingOpeningHand
            || !canEndTurn
            || isShowingBattleLog
            || overlayCombatantDetail != nil
            || overlayAbilityDetail != nil
    }

    private func waitWhileAutoBattleBlocked(
        isBlocked: @MainActor () -> Bool,
    ) async {
        while !Task.isCancelled, isAutoBattleEnabled, isBlocked() {
            await waitForAutoBattleRetry()
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
        _ operation: () throws -> Result,
    ) rethrows -> Result {
        let interval = BattleFramePacingSignposts.signposter.beginInterval(name)
        defer {
            BattleFramePacingSignposts.signposter.endInterval(name, interval)
        }
        return try operation()
    }
}
