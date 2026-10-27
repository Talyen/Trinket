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
        handDeparture: (id: UUID, card: BattleCard)? = nil,
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
        let actionEventIDs = Set(playback.actions.lazy.flatMap(\.eventIDs))
        let standaloneDraws = playback.events.filter {
            $0.effectKind == .cardsDrawn && !actionEventIDs.contains($0.id)
        }
        let hasImplicitDeal = playback.snapshot.hand.contains { !previousIDs.contains($0.id) }
            && !playback.events.contains { $0.effectKind == .cardsDrawn }
        if !standaloneDraws.isEmpty || hasImplicitDeal {
            feedback.record(standaloneDraws, at: date, environment: dependencies, didDrawCards: hasImplicitDeal)
        }
        withAnimation(BattleMotion.handReflow) {
            presentation.install(snapshot, includeCombatants: false)
        }
        let configurationID = playback.configurationID
        let changesByEventID = Dictionary(grouping: playback.combatantChanges, by: \.eventID)
        feedback.scheduleActions(
            playback, preparedCardID: preparedCardID,
            at: date, cardPlayback: cardPlayback,
            handDeparture: handDeparture,
        ) { [weak self] events, damage, impactAt, groupID in
            guard let self, activeBattle?.id == configurationID else { return }
            let enemyWasAlive = (presentation.enemy?.health ?? 0) > 0
            presentation.apply(events.sorted { $0.id < $1.id }.flatMap { changesByEventID[$0.id] ?? [] })
            feedback.record(
                events.filter { $0.milestone == nil },
                at: impactAt,
                environment: dependencies,
                actionGroupID: groupID,
                damage: damage,
            )
            if enemyWasAlive, presentation.enemy?.health == 0, commandState.phase == .outcome, outcome == .victory {
                publishPartyCelebrateReactions(at: impactAt)
            }
        }
        commandState.transition(to: .ready)
        handleOutcomeIfNeeded(at: date)
        scheduleAutoEndIfNeeded()
    }

    func beginTurnPresentation(at date: Date) {
        guard let playback = resolveTransition(.turn) else { return }
        playPresentationSFX(SFXID.endTurn)
        presentCompletedCommand(playback, at: date)
    }

    func beginOpeningHandDeal(for configurationID: UUID) {
        guard hasActiveSimulation, engineHand.isEmpty, activeBattle?.id == configurationID else { return }
        commandState.transition(to: .opening)
        if !isSuspendedForScenePhase {
            presentOpeningTransition(for: configurationID)
            return
        }
        let generation = transitionTask.claim()
        transitionTask.task = Task { @MainActor [weak self] in
            defer { self?.transitionTask.finish(generation: generation) }
            // A backgrounded opening can wait indefinitely. The wait must not
            // retain the session whose teardown owns its cancellation.
            while !Task.isCancelled, self?.isSuspendedForScenePhase == true {
                // Sleep even for `.zero` delays: a bare `yield` loop hot-spins
                // while suspended. The 5ms floor keeps wake latency negligible.
                let delay = max(self?.autoBattleRetryDelay ?? .zero, .milliseconds(5))
                try? await Task.sleep(for: delay)
            }
            guard let self, !Task.isCancelled, transitionTask.isCurrent(generation) else { return }
            presentOpeningTransition(for: configurationID)
        }
    }

    private func presentOpeningTransition(for configurationID: UUID) {
        guard activeBattle?.id == configurationID,
              let playback = resolveTransition(.opening)
        else { return }
        presentCompletedCommand(playback, at: .now)
    }

    func cancelTransitionPresentation() {
        transitionTask.invalidate()
        cardPlayback.reset()
        commandState.transition(to: .inactive)
    }
}
