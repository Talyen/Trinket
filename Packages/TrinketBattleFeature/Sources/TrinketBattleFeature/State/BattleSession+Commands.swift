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
        isAutomatic: Bool = false,
        departureID: UUID? = nil,
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
            let handDeparture: (id: UUID, card: BattleCard)? = if isAutomatic, let departureID,
                                                                  let card = engineState?.hand.card(id: cardID) {
                (departureID, card)
            } else {
                nil
            }
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

            let preparedCardID = cardCues.current.flatMap {
                $0.cardID == cardID && $0.phase == .lifted && $0.mode == .preview ? cardID : nil
            }
            cardCues.commit(cardID: cardID)

            isShowingAutoBattlePauseNotice = false
            cancelPendingAutoEnd()
            presentCompletedCommand(
                resolution.playback, at: date, playedCardID: cardID, preparedCardID: preparedCardID,
                isAutomatic: isAutomatic, handDeparture: handDeparture,
            )
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
        isShowingAutoBattlePauseNotice = false
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
              !isShowingAutoBattlePauseNotice,
              canEndTurn,
              !hasPlayableCard
        else { return }

        let generation = autoEnd.claim()
        let delay = autoEndTurnDelay
        autoEnd.task = Task { @MainActor [weak self] in
            defer {
                self?.autoEnd.finish(generation: generation)
            }
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled,
                  autoEnd.isCurrent(generation),
                  !isSuspendedForScenePhase,
                  !isShowingAutoBattlePauseNotice,
                  canEndTurn,
                  !hasPlayableCard
            else { return }

            endTurn()
        }
    }

    func driveAutoBattle(
        input: BattleViewInput,
        isCardCastPacingBlocked: @escaping @MainActor () -> Bool,
        isManualInteractionActive: @escaping @MainActor () -> Bool,
        playCard: @MainActor (BattleCard) async -> Bool,
    ) async {
        guard let initialState = engineState else { return }
        var progress = AutoBattleProgress(in: initialState)
        let autoBattlePolicy = PlayPolicy.greedy
        while input.isCurrent(in: self), !Task.isCancelled, isAutoBattleEnabled {
            guard hasRunnableAutoBattle else { return }

            if isAutoBattlePresentationBlocked {
                await waitForAutoBattleRetry()
                continue
            }

            await waitWhileAutoBattleBlocked(input: input, isBlocked: isManualInteractionActive)
            await waitWhileAutoBattleBlocked(input: input, isBlocked: isCardCastPacingBlocked)
            guard input.isCurrent(in: self), !Task.isCancelled, isAutoBattleEnabled, hasRunnableAutoBattle else {
                return
            }
            if isAutoBattlePresentationBlocked || isManualInteractionActive() {
                continue
            }

            guard let engineState else { return }
            if progress.shouldPause(in: engineState) {
                isShowingAutoBattlePauseNotice = true
                cancelPendingAutoEnd()
                isAutoBattleEnabled = false
                return
            }
            guard let card = autoBattlePolicy.preferredPlayableCard(in: engineState)
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
            guard input.isCurrent(in: self), !Task.isCancelled, isAutoBattleEnabled, outcome == nil else { return }

            await waitWhileAutoBattleBlocked(input: input, isBlocked: isCardCastPacingBlocked)
        }
    }

    private var hasRunnableAutoBattle: Bool {
        activeBattle != nil && outcome == nil
    }

    private var isAutoBattlePresentationBlocked: Bool {
        !canAcceptBattleCommands
    }

    private func waitWhileAutoBattleBlocked(
        input: BattleViewInput,
        isBlocked: @MainActor () -> Bool,
    ) async {
        while input.isCurrent(in: self), !Task.isCancelled, isAutoBattleEnabled, isBlocked() {
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
