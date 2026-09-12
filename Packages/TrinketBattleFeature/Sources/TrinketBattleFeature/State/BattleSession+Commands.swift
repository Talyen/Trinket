import BattleEngine
import Foundation
import os

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
        if commandState.phase == .outcome {
            guard canInteractWithHand, presentation.consumeFinishingCard(id: cardID) else { return .rejected }
            return .committed
        }
        guard !requiresLift || cardCues.hasLift(for: cardID) else { return .rejected }
        feedback.pruneExpired(at: date)
        guard canAcceptBattleCommands
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
            let resolution = try measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardEngine,
            ) {
                try playEngineCard(cardID: cardID)
            }
            guard hasActiveSimulation, activeBattle != nil else {
                return .rejected
            }

            cardCues.commit(cardID: cardID)

            cancelPendingAutoEnd()
            presentCompletedCommand(resolution.playback, at: date, playedCardID: cardID)
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
        cancelPendingAutoEnd()
        feedback.pruneExpired(at: date)
        guard canEndTurn, hasActiveSimulation, !isSuspendedForScenePhase else {
            feedback.noteItemsChanged()
            return
        }
        clearCardCues()

        let transitionInterval = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.turnTransition,
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.turnTransition,
                transitionInterval,
            )
        }

        beginTurnPresentation(at: date)
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
            if isAutoBattlePresentationBlocked || isManualInteractionActive() {
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
        !canAcceptBattleCommands
    }

    private func waitWhileAutoBattleBlocked(
        isBlocked: @MainActor () -> Bool,
    ) async {
        while !Task.isCancelled, isAutoBattleEnabled, isBlocked() {
            await waitForAutoBattleRetry()
        }
    }

    func waitForAutoBattleRetry() async {
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
