import BattleEngine
import Foundation
import SwiftUI
import TrinketContent

extension BattleSession {
    func beginTurnPresentation(at date: Date) {
        commandState.transition(to: .turn)
        guard let playback = resolveTransition(.turn) else {
            commandState.transition(to: .inactive)
            return
        }
        transitionPlayback = playback
        if openingHandDrawStagger <= .zero {
            finishImmediately(playback, at: date)
            return
        }
        _ = presentNextTransitionFrame(at: date)
        scheduleTransitionPlayback()
    }

    func beginOpeningHandDeal(for configurationID: UUID, startDelay: Duration = .zero) {
        guard hasActiveSimulation, engineHand.isEmpty, activeBattle?.id == configurationID else { return }
        commandState.transition(to: .opening)
        if openingHandDrawStagger <= .zero, !isSuspendedForScenePhase {
            guard let playback = resolveTransition(.opening) else { return }
            finishImmediately(playback, at: .now)
            return
        }
        let generation = transitionTask.claim()
        transitionTask.task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { transitionTask.finish(generation: generation) }
            if startDelay > .zero {
                try? await Task.sleep(for: startDelay)
            }
            await CombatFeedbackDisplayLinkGate.waitForNextDisplayLink()
            await waitForSceneActivation()
            guard !Task.isCancelled, transitionTask.isCurrent(generation),
                  activeBattle?.id == configurationID,
                  let playback = resolveTransition(.opening) else { return }
            transitionPlayback = playback
            await playTransition(generation: generation)
        }
    }

    func cancelTransitionPresentation() {
        transitionTask.invalidate()
        transitionPlayback = nil
        commandState.transition(to: .inactive)
    }

    private func scheduleTransitionPlayback() {
        guard transitionPlayback != nil else { return }
        let generation = transitionTask.claim()
        transitionTask.task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { transitionTask.finish(generation: generation) }
            await playTransition(generation: generation)
        }
    }

    private func playTransition(generation: Int) async {
        while true {
            await waitForSceneActivation()
            guard !Task.isCancelled, transitionTask.isCurrent(generation),
                  let playback = transitionPlayback, activeBattle?.id == playback.configurationID else { return }
            guard let checkpoint = presentNextTransitionFrame(at: .now) else { return }
            if checkpoint == .cardDrawn || checkpoint == .bufferPromoted {
                if openingHandDrawStagger > .zero {
                    try? await Task.sleep(for: openingHandDrawStagger)
                }
            }
        }
    }

    private func presentNextTransitionFrame(at date: Date) -> BattleTransitionCheckpoint? {
        guard let frame = transitionPlayback?.next() else { return nil }
        withAnimation(BattleMotion.deal) {
            presentation.install(frame.snapshot)
        }
        if frame.checkpoint == .cardDrawn || frame.checkpoint == .bufferPromoted {
            dependencies.playSFX([SFXID.abilityDraw])
        }
        presentResolvedEvents(frame.events, at: date)
        if frame.checkpoint == .ready {
            finishTransition(at: date)
            return nil
        }
        return frame.checkpoint
    }

    private func finishImmediately(_ playback: BattleTransitionPlayback, at date: Date) {
        if let snapshot = playback.frames.last?.snapshot {
            presentation.install(snapshot)
        }
        if playback.frames.contains(where: { $0.checkpoint == .cardDrawn }) {
            dependencies.playSFX([SFXID.abilityDraw])
        }
        presentResolvedEvents(playback.frames.flatMap(\.events), at: date)
        finishTransition(at: date)
    }

    private func finishTransition(at date: Date) {
        transitionPlayback = nil
        commandState.transition(to: isBattleOver ? .outcome : .ready)
        handleOutcomeIfNeeded(at: date)
        scheduleAutoEndIfNeeded()
    }

    private func waitForSceneActivation() async {
        while !Task.isCancelled, isSuspendedForScenePhase {
            await waitForAutoBattleRetry()
        }
    }
}
