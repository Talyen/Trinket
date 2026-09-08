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
        requiresLift: Bool = false,
    ) -> BattleCardPlayResolution {
        guard !requiresLift || cardCues.hasLift(for: cardID) else { return .rejected }
        cancelPendingAutoEnd()
        feedback.pruneExpired(at: date, notifyPresentation: false)
        guard spectacle.outcomePresentation == .battle,
              hasActiveSimulation,
              !isBattleOver,
              !isSuspendedForScenePhase
        else {
            clearCardCues()
            feedback.noteItemsChanged()
            return .rejected
        }

        do {
            if cardCues.current?.cardID == cardID, let card = engineState?.hand.card(id: cardID) {
                if let assessment = engineState?.assessCard(card), assessment.denial == nil {
                    cardCues.begin(cardID: cardID, assessment: assessment)
                }
            }
            let events = try measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardEngine,
            ) {
                try playEngineCard(cardID: cardID)
            }
            guard hasActiveSimulation, activeBattle != nil else {
                return .rejected
            }

            cardCues.commit(cardID: cardID)

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
        } catch {
            if let card = engineState?.hand.card(id: cardID) {
                denyCardCue(card)
            }
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
        clearCardCues()
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

        if openingHandDrawStagger <= .zero {
            performAtomicTurnTransition(at: date)
            return
        }
        performSequentialTurnTransition(at: date)
    }

    private func commitEngineEvents(_ events: [ActionEvent], at date: Date) {
        presentResolvedEvents(events, at: date)
        handleOutcomeIfNeeded(at: date)
        if isBattleOver || outcome != nil {
            installSimulationPresentation()
        }
        scheduleAutoEndIfNeeded()
    }

    private func performAtomicTurnTransition(at date: Date) {
        let events = endEngineTurn()
        if hasActiveSimulation {
            installSimulationPresentation()
            if phase == .playerTurn {
                dependencies.playSFX([SFXID.abilityDraw])
            }
        }
        commitEngineEvents(events, at: date)
    }

    private func performSequentialTurnTransition(at date: Date) {
        let generation = turnDraw.claim()

        let preEvents = endTurnWithoutDraw()
        if hasActiveSimulation {
            installSimulationPresentation()
        }
        presentResolvedEvents(preEvents, at: date)
        handleOutcomeIfNeeded(at: date)
        if isBattleOver || outcome != nil {
            installSimulationPresentation()
            scheduleAutoEndIfNeeded()
            return
        }

        turnDraw.task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                turnDraw.finish(generation: generation)
            }
            await runSequentialTurnDraw(generation: generation)
        }
    }

    private func runSequentialTurnDraw(generation: Int) async {
        while true {
            guard !Task.isCancelled,
                  turnDraw.isCurrent(generation),
                  hasActiveSimulation,
                  activeBattle != nil
            else {
                return
            }
            let drew = withAnimation(BattleMotion.deal) {
                let ok = drawNextTurnStartCard()
                if ok {
                    installSimulationPresentation()
                    dependencies.playSFX([SFXID.abilityDraw])
                }
                return ok
            }
            if !drew {
                break
            }
            let stagger = openingHandDrawStagger
            if stagger > .zero {
                try? await Task.sleep(for: stagger)
            }
            await drainTurnBufferPromotions(generation: generation, stagger: stagger)
        }

        guard !Task.isCancelled,
              turnDraw.isCurrent(generation),
              hasActiveSimulation
        else {
            return
        }

        await drainTurnBufferPromotions(generation: generation, stagger: openingHandDrawStagger)

        guard !Task.isCancelled,
              turnDraw.isCurrent(generation),
              hasActiveSimulation
        else {
            return
        }

        let postEvents = finalizeTurnStart()
        withAnimation(BattleMotion.deal) {
            installSimulationPresentation()
        }
        commitEngineEvents(postEvents, at: .now)
    }

    private func drainTurnBufferPromotions(generation: Int, stagger: Duration) async {
        while true {
            guard !Task.isCancelled,
                  turnDraw.isCurrent(generation),
                  hasActiveSimulation
            else {
                return
            }
            let promoted = withAnimation(BattleMotion.deal) {
                if promoteNextTurnBufferCard() != nil {
                    installSimulationPresentation()
                    dependencies.playSFX([SFXID.abilityDraw])
                    return true
                }
                return false
            }
            if !promoted {
                break
            }
            if stagger > .zero {
                try? await Task.sleep(for: stagger)
            }
        }
    }

    func cancelPendingTurnDraw() {
        turnDraw.invalidate()
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
            dependencies.playSFX([SFXID.abilityDraw])
            commitEngineEvents(events, at: .now)
            return
        }

        let generation = openingHandDeal.claim()
        isDealingOpeningHand = true
        openingHandDeal.task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if openingHandDeal.isCurrent(generation) {
                    isDealingOpeningHand = false
                    openingHandDeal.task = nil
                }
            }

            guard await waitForOpeningHandDealStart(
                configurationID: configurationID,
                startDelay: startDelay,
            ) else { return }

            dependencies.playSFX([SFXID.abilityDraw])

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
            commitEngineEvents(events, at: .now)
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
        openingHandDeal.invalidate()
        isDealingOpeningHand = false
    }

    func cancelPendingAutoEnd() {
        autoEnd.invalidate()
    }

    func scheduleAutoEndIfNeeded() {
        cancelPendingAutoEnd()
        guard !isSuspendedForScenePhase,
              canEndTurn,
              !hasPlayableCard
        else { return }

        let generation = autoEnd.claim()
        autoEnd.task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                autoEnd.finish(generation: generation)
            }
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
                    else {
                        return
                    }
                }
            }

            endTurn()
        }
    }

    func driveAutoBattle(
        isCardCastActive: @escaping @MainActor () -> Bool,
        isManualInteractionActive: @escaping @MainActor () -> Bool,
        playCard: @MainActor (BattleCard) async -> Bool,
    ) async {
        let autoBattlePolicy = PlayPolicy.greedy
        while !Task.isCancelled, isAutoBattleEnabled {
            guard hasRunnableAutoBattle else { return }

            if isAutoBattlePresentationBlocked {
                await waitForAutoBattleRetry()
                continue
            }

            await waitWhileAutoBattleBlocked(isBlocked: isManualInteractionActive)
            await waitWhileAutoBattleBlocked(isBlocked: isCardCastActive)
            guard !Task.isCancelled, isAutoBattleEnabled, hasRunnableAutoBattle else {
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

    private var hasRunnableAutoBattle: Bool {
        activeBattle != nil && outcome == nil
    }

    private var isAutoBattlePresentationBlocked: Bool {
        isSuspendedForScenePhase
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
