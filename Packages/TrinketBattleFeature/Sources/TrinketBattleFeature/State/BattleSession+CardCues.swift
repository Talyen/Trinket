import BattleEngine
import Foundation
import TrinketContent

extension BattleSession {
    func beginCardCue(
        _ card: BattleCard,
        mode: BattleCardCuePresentationMode = .preview,
        at date: Date = .now,
    ) {
        guard canPresentCardCue, let state = engineState else { return }
        if cardCues.current?.cardID == card.id, cardCues.current?.phase == .lifted {
            if mode == .preview, cardCues.current?.mode == .pressPreview {
                let assessment = state.assessCard(card)
                guard assessment.denial == nil else { return }
                cardCues.begin(cardID: card.id, assessment: assessment, mode: mode, at: date)
            }
            return
        }
        let assessment = state.assessCard(card)
        guard assessment.denial == nil else { return }
        if let previous = cardCues.current, previous.phase == .lifted, previous.cardID != card.id {
            publishAttackTelegraph(.cancel, for: previous.actorID)
        }
        cardCues.begin(cardID: card.id, assessment: assessment, mode: mode, at: date)
        if card.ability.dealsCombatDamage, mode != .tapCommit {
            feedback.previewAttack(.windUp, for: assessment.actorID, at: date)
        }
    }

    func cancelCardCue(_ card: BattleCard) {
        if let cue = cardCues.current, cue.cardID == card.id, cue.phase == .lifted {
            publishAttackTelegraph(.cancel, for: cue.actorID)
        }
        cardCues.cancel(cardID: card.id)
    }

    func denyCardCue(_ card: BattleCard) {
        guard canPresentCardCue, let state = engineState, let reason = state.assessCard(card).denial else {
            cancelCardCue(card)
            return
        }
        let actor = state.roster[card.owner]
        cardCues.deny(cardID: card.id, actorID: actor.id, reason: reason)
    }

    func clearCardCues() {
        if let cue = cardCues.current, cue.phase == .lifted {
            publishAttackTelegraph(.cancel, for: cue.actorID)
        }
        cardCues.clear()
    }

    var canPresentCardCue: Bool {
        spectacle.outcomePresentation == .battle && hasActiveSimulation && !isSuspendedForScenePhase
            && !hasBlockingOverlay
    }
}
