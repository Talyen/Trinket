import BattleEngine
import Foundation
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

/// Owns commands and asynchronous pacing for one active BattleSession run.
///
/// The runtime remains the only owner of mutable simulation state. This object
/// sequences runtime transitions with the existing presentation lanes while
/// keeping task cancellation and timing seams out of the observable session.
@MainActor
final class BattleCommandCoordinator {
    weak var session: BattleSession?
    let runtime: BattleRuntimeSession

    var onTurnAutoEnded: ((Int?) -> Void)?
    var openingHandDrawStagger: TimeInterval

    private let autoEndTurnDelay: TimeInterval
    private let enemyAttackImpactDelayOverride: TimeInterval?
    private var pendingAutoEndTask: Task<Void, Never>?
    private var pendingOpeningHandDealTask: Task<Void, Never>?
    private var openingHandDealGeneration = 0

    private(set) var isDealingOpeningHand = false

    init(
        session: BattleSession,
        runtime: BattleRuntimeSession,
        autoEndTurnDelay: TimeInterval,
        openingHandDrawStagger: TimeInterval,
        enemyAttackImpactDelayOverride: TimeInterval?
    ) {
        self.session = session
        self.runtime = runtime
        self.autoEndTurnDelay = autoEndTurnDelay
        self.openingHandDrawStagger = openingHandDrawStagger
        self.enemyAttackImpactDelayOverride = enemyAttackImpactDelayOverride
    }

    var hasPendingAutoEnd: Bool {
        pendingAutoEndTask != nil
    }

    @discardableResult
    func playCard(
        cardID: Int,
        at date: Date = .now
    ) -> BattleCardPlayResolution {
        guard let session else { return .rejected }

        cancelPendingAutoEnd()
        session.feedback.pruneExpired(at: date, notifyPresentation: false)
        session.pruneExpiredSkillCallout(at: date)
        session.pruneSoftHold(at: date)
        guard session.spectacle.activeCinematic == nil,
              !session.spectacle.isShowingVictory,
              !session.spectacle.isShowingDefeat,
              !isDealingOpeningHand,
              runtime.hasActiveSimulation,
              !runtime.isBattleOver
        else {
            session.feedback.noteItemsChanged()
            return .rejected
        }

        do {
            let events = try measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardEngine
            ) {
                try runtime.playCard(cardID: cardID)
            }
            guard runtime.hasActiveSimulation, session.activeBattle?.id != nil else {
                return .rejected
            }

            measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardProjection
            ) {
                session.installSimulationPresentation()
            }
            measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardFeedback
            ) {
                session.presentResolvedEvents(events, at: date)
            }
            let earnedGold = session.handleOutcomeIfNeeded(at: date)
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
            session.feedback.noteItemsChanged()
            return .rejected
        }
    }

    @discardableResult
    func endTurn(at date: Date = .now) -> Int? {
        guard let session else { return nil }

        cancelPendingAutoEnd()
        session.feedback.pruneExpired(at: date, notifyPresentation: false)
        session.pruneExpiredSkillCallout(at: date)
        session.pruneSoftHold(at: date)
        guard session.canEndTurn, runtime.hasActiveSimulation else {
            session.feedback.noteItemsChanged()
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
            session.installSimulationPresentation()
            if runtime.phase == .playerTurn {
                session.presentationEnvironment.playSFX([SFXID.abilityDraw])
            }
        }
        session.presentResolvedEvents(events, at: date)
        let earnedGold = session.handleOutcomeIfNeeded(at: date)
        if earnedGold == nil {
            scheduleAutoEndIfNeeded()
        }
        return earnedGold
    }

    func beginOpeningHandDeal(for configurationID: UUID) {
        guard let session,
              runtime.hasActiveSimulation,
              runtime.hand.isEmpty,
              session.activeBattle?.id == configurationID
        else { return }

        if openingHandDrawStagger <= 0 {
            _ = runtime.drawOpeningHand()
            session.installSimulationPresentation()
            session.presentationEnvironment.playSFX([SFXID.abilityDraw])
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
                  let session = self.session,
                  session.activeBattle?.id == configurationID
            else { return }

            session.presentationEnvironment.playSFX([SFXID.abilityDraw])

            while true {
                guard !Task.isCancelled,
                      session.activeBattle?.id == configurationID,
                      runtime.hasActiveSimulation
                else { return }

                let drew = withAnimation(TrinketMotion.Battle.deal) {
                    let didDraw = runtime.drawNextOpeningHandCard()
                    if didDraw {
                        session.installSimulationPresentation()
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
                  session.activeBattle?.id == configurationID,
                  runtime.hasActiveSimulation
            else { return }

            runtime.finalizeOpeningHand()
            session.installSimulationPresentation()
            scheduleAutoEndIfNeeded()
        }
    }

    func cancelOpeningHandDeal() {
        openingHandDealGeneration &+= 1
        pendingOpeningHandDealTask?.cancel()
        pendingOpeningHandDealTask = nil
        isDealingOpeningHand = false
    }

    func considerAutoEndTurn() {
        scheduleAutoEndIfNeeded()
    }

    func cancelPendingAutoEnd() {
        pendingAutoEndTask?.cancel()
        pendingAutoEndTask = nil
    }

    func scheduleAutoEndIfNeeded() {
        cancelPendingAutoEnd()
        guard let session,
              !session.isSuspendedForScenePhase,
              session.canEndTurn,
              !session.hasPlayableCard
        else { return }

        pendingAutoEndTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(autoEndTurnDelay))
            guard !Task.isCancelled,
                  let session = self.session,
                  !session.isSuspendedForScenePhase,
                  session.canEndTurn,
                  !session.hasPlayableCard
            else { return }

            if shouldTelegraphEnemyAttack(), let enemyID = runtime.enemyID {
                session.publishFullAttack(for: enemyID)
                let impactDelay = enemyAttackImpactDelayOverride
                    ?? CombatFeedbackAttackRecipes.cardAttack(for: .attack).impactDelay
                if impactDelay > 0 {
                    try? await Task.sleep(for: .seconds(impactDelay))
                    guard !Task.isCancelled,
                          !session.isSuspendedForScenePhase,
                          session.canEndTurn,
                          !session.hasPlayableCard
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
        isAutoBattleEnabled: @escaping @MainActor () -> Bool,
        isCardCastActive: @escaping @MainActor () -> Bool,
        isManualInteractionActive: @escaping @MainActor () -> Bool,
        playCard: @escaping @MainActor (BattleCard) -> Bool
    ) async {
        while !Task.isCancelled, isAutoBattleEnabled() {
            guard let session,
                  session.activeBattle != nil,
                  session.outcome == nil
            else { return }

            if session.isSuspendedForScenePhase
                || !session.canEndTurn
                || session.isShowingBattleLog
                || session.overlayCombatantDetail != nil
                || session.overlayAbilityDetail != nil
                || isManualInteractionActive()
                || isCardCastActive() {
                await waitForAutoBattleRetry()
                continue
            }

            guard let card = session.hand.first(where: { session.isCardPlayable($0) }) else {
                if !hasPendingAutoEnd {
                    scheduleAutoEndIfNeeded()
                }
                await waitForAutoBattleRetry()
                continue
            }

            guard playCard(card) else { return }
            guard !Task.isCancelled, isAutoBattleEnabled(), session.outcome == nil else { return }

            while !Task.isCancelled, isAutoBattleEnabled(), isCardCastActive() {
                await waitForAutoBattleRetry()
            }
        }
    }

    private func waitForAutoBattleRetry() async {
        try? await Task.sleep(for: .milliseconds(50))
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
