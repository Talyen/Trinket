import BattleEngine
import Foundation
import SwiftUI
import TrinketContent

extension BattleSession {
    func presentCompletedCommand(_ playback: BattleTransitionPlayback, at date: Date, playedCardID: Int? = nil) {
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
        cardPlayback.append(playback.automaticCards, at: date)
        presentResolvedEvents(playback.events, at: date)
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
