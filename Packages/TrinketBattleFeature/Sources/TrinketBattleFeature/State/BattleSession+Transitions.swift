import BattleEngine
import Foundation
import SwiftUI
import TrinketContent

extension BattleSession {
    func restoreRecordedCardCue() {
        guard let cardID = cardPlayback.liftedCardID,
              let playback = transitionPlayback,
              playback.nextIndex > 0,
              playback.nextIndex <= playback.frames.count else { return }
        let frame = playback.frames[playback.nextIndex - 1]
        guard let assessment = frame.assessment else { return }
        cardCues.begin(cardID: cardID, assessment: assessment, mode: .preview)
        if case let .cardWillPlay(card) = frame.checkpoint, card.ability.dealsCombatDamage {
            publishAttackTelegraph(.windUp, for: assessment.actorID)
        }
    }

    func beginCardPresentation(_ playback: BattleTransitionPlayback, at date: Date) {
        commandState.transition(to: .card)
        transitionPlayback = playback
        if openingHandDrawStagger <= .zero {
            finishImmediately(playback, at: date)
            return
        }
        while let checkpoint = presentNextTransitionFrame(at: date) {
            if case .cardPlayed = checkpoint {
                break
            }
        }
        scheduleTransitionPlayback()
    }

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
        cardPlayback.reset()
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
                  let playback = transitionPlayback, activeBattle?.id == playback.configurationID,
                  playback.nextIndex < playback.frames.count else { return }
            let next = playback.frames[playback.nextIndex]
            if playback.initialCardID != nil,
               next.checkpoint == .ready || next.assessment != nil {
                guard await waitForCardPlaybackDelay(.seconds(BattleMotion.cardActivationDuration), generation: generation) else { return }
            }
            guard let checkpoint = presentNextTransitionFrame(at: .now) else { return }
            if case let .cardWillPlay(card) = checkpoint {
                guard await waitForCardPlaybackDelay(.seconds(BattleMotion.cardDealDuration), generation: generation) else { return }
                if let assessment = next.assessment {
                    cardCues.begin(cardID: card.id, assessment: assessment, mode: .preview)
                    if card.ability.dealsCombatDamage {
                        publishAttackTelegraph(.windUp, for: assessment.actorID)
                    }
                }
                cardPlayback.liftedCardID = card.id
                guard await waitForCardPlaybackDelay(.seconds(BattleMotion.tapLiftPlayDelay), generation: generation) else { return }
            }
            if checkpoint == .cardDrawn || checkpoint == .bufferPromoted {
                if openingHandDrawStagger > .zero {
                    try? await Task.sleep(for: openingHandDrawStagger)
                }
            }
        }
    }

    private func presentNextTransitionFrame(at date: Date) -> BattleTransitionCheckpoint? {
        guard let frame = transitionPlayback?.next() else { return nil }
        if case let .cardPlayed(card) = frame.checkpoint, card.id != transitionPlayback?.initialCardID {
            cardPlayback.play(card, hand: presentation.hand, stagedCard: presentation.stagedCard)
            cardCues.commit(cardID: card.id)
            if card.ability.dealsCombatDamage, let actorID = combatantID(for: card.owner) {
                publishAttackTelegraph(.swing, for: actorID)
            }
        }
        if transitionPlayback?.initialCardID != nil, frame.assessment == nil {
            presentation.install(frame.snapshot)
        } else {
            withAnimation(BattleMotion.deal) {
                presentation.install(frame.snapshot)
            }
        }
        if frame.checkpoint == .cardDrawn || frame.checkpoint == .bufferPromoted {
            dependencies.playSFX([SFXID.abilityDraw])
        }
        if case let .cardWillPlay(card) = frame.checkpoint, card.id != transitionPlayback?.initialCardID {
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
        if playback.hasAutomaticDraws
            || playback.frames.contains(where: { $0.checkpoint == .cardDrawn || $0.checkpoint == .bufferPromoted }) {
            dependencies.playSFX([SFXID.abilityDraw])
        }
        presentResolvedEvents(playback.frames.flatMap(\.events), at: date)
        finishTransition(at: date)
    }

    private func finishTransition(at date: Date) {
        transitionPlayback = nil
        cardPlayback.reset()
        commandState.transition(to: isBattleOver ? .outcome : .ready)
        handleOutcomeIfNeeded(at: date)
        scheduleAutoEndIfNeeded()
    }

    private func waitForSceneActivation() async {
        while !Task.isCancelled, isSuspendedForScenePhase {
            await waitForAutoBattleRetry()
        }
    }

    private func waitForCardPlaybackDelay(_ duration: Duration, generation: Int) async -> Bool {
        var remaining = cardPlayback.delayOverride ?? duration
        let clock = ContinuousClock()
        while remaining > .zero {
            await waitForSceneActivation()
            guard !Task.isCancelled, transitionTask.isCurrent(generation), transitionPlayback != nil else { return false }
            let started = clock.now
            try? await Task.sleep(for: min(remaining, .milliseconds(50)))
            if !isSuspendedForScenePhase {
                remaining -= started.duration(to: clock.now)
            }
        }
        await waitForSceneActivation()
        return !Task.isCancelled && transitionTask.isCurrent(generation) && transitionPlayback != nil
    }
}
