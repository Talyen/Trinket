import BattleEngine
import TrinketContent
import TrinketCore

extension BattleSession {
    func beginCardCue(
        _ card: BattleCard,
        mode: BattleCardCuePresentationMode = .preview,
    ) {
        guard canPresentCardCue, let state = engineState else { return }
        if cardCues.current?.cardID == card.id, cardCues.current?.phase == .lifted {
            return
        }
        let assessment = state.assessCard(card)
        guard assessment.denial == nil else { return }
        if let previous = cardCues.current, previous.phase == .lifted, previous.cardID != card.id {
            publishAttackTelegraph(.cancel, for: previous.actorID)
        }
        cardCues.begin(cardID: card.id, assessment: assessment, mode: mode)
        if card.ability.dealsCombatDamage {
            publishAttackTelegraph(.windUp, for: assessment.actorID)
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
        let keyword = actor.activeEffects.first { [.stun, .freeze].contains($0.effect.keyword) }?.effect.keyword
        cardCues.deny(cardID: card.id, actorID: actor.id, reason: reason, controlKeyword: keyword)
    }

    func clearCardCues() {
        if let cue = cardCues.current, cue.phase == .lifted {
            publishAttackTelegraph(.cancel, for: cue.actorID)
        }
        cardCues.clear()
    }

    var canPresentCardCue: Bool {
        spectacle.outcomePresentation == .battle && hasActiveSimulation && !isSuspendedForScenePhase
            && overlayAbilityDetail == nil && overlayCombatantDetail == nil && !isShowingBattleLog
    }
}
