import BattleEngine
import Foundation
import SwiftUI
import TrinketContent

extension BattleSession {
    func presentCompletedCommand(
        _ playback: BattleTransitionPlayback,
        at date: Date,
        playedCardID: Int? = nil,
        preparedCardID: Int? = nil,
        isAutomatic: Bool = false,
    ) {
        guard activeBattle?.id == playback.configurationID else { return }
        let previousIDs = Set(presentation.hand.map(\.id))
        var snapshot = playback.snapshot
        if snapshot.isBattleOver {
            let consumedIDs = Set(playback.automaticCards.map(\.id)).union(playedCardID.map { [$0] } ?? [])
            let remaining = presentation.hand.filter { !consumedIDs.contains($0.id) }
            let remainingIDs = Set(remaining.map(\.id))
            snapshot.hand = Array((remaining + snapshot.hand.filter { !remainingIDs.contains($0.id) })
                .prefix(BattleHand.maxSize))
        }
        if playback.snapshot.hand.contains(where: { !previousIDs.contains($0.id) })
            || playback.events.contains(where: { $0.effectKind == .cardsDrawn }) {
            dependencies.playSFX([SFXID.abilityDraw])
        }
        withAnimation(BattleMotion.handReflow) {
            presentation.install(snapshot)
        }
        let configurationID = playback.configurationID
        presentUltimateHighlight(playback.events, at: date)
        feedback.scheduleActions(
            playback, preparedCardID: preparedCardID, playedCardID: isAutomatic ? nil : playedCardID,
            at: date, cardPlayback: cardPlayback,
        ) { [weak self] events, damage, impactAt, groupID in
            guard let self, activeBattle?.id == configurationID else { return }
            feedback.record(
                events.filter { $0.kind != .milestone },
                at: impactAt,
                environment: dependencies,
                actionGroupID: groupID,
                damage: damage,
            )
        }
        commandState.transition(to: .ready)
        handleOutcomeIfNeeded(at: date)
        scheduleAutoEndIfNeeded()
    }

    func beginTurnPresentation(at date: Date) {
        guard let playback = resolveTransition(.turn) else { return }
        presentCompletedCommand(playback, at: date)
    }

    func beginOpeningHandDeal(for configurationID: UUID) {
        guard hasActiveSimulation, engineHand.isEmpty, activeBattle?.id == configurationID else { return }
        commandState.transition(to: .opening)
        if !isSuspendedForScenePhase {
            guard let playback = resolveTransition(.opening) else { return }
            presentCompletedCommand(playback, at: .now)
            return
        }
        let generation = transitionTask.claim()
        transitionTask.task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { transitionTask.finish(generation: generation) }
            while !Task.isCancelled, isSuspendedForScenePhase {
                await waitForAutoBattleRetry()
            }
            guard !Task.isCancelled, transitionTask.isCurrent(generation),
                  activeBattle?.id == configurationID,
                  let playback = resolveTransition(.opening) else { return }
            presentCompletedCommand(playback, at: .now)
        }
    }

    func cancelTransitionPresentation() {
        transitionTask.invalidate()
        cardPlayback.reset()
        commandState.transition(to: .inactive)
    }
}
