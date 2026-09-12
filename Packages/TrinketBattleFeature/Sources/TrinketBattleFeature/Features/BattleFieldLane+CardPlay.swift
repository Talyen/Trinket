import BattleEngine
import SwiftUI

extension BattleFieldLane {
    var autoBattleTaskID: String {
        "\(battleSession.isAutoBattleEnabled)-\(battleSession.activeBattle?.id.uuidString ?? "none")"
    }

    func playCardWithTapLift(_ card: BattleCard, battleSize: CGSize) async -> Bool {
        battleSession.beginCardCue(card, mode: .preview)
        interactionState.suppressCombatantTaps = false
        interactionState.autoLiftCardID = card.id
        defer {
            if interactionState.autoLiftCardID == card.id {
                interactionState.autoLiftCardID = nil
            }
        }

        try? await Task.sleep(for: .seconds(BattleMotion.tapLiftPlayDelay))
        guard !Task.isCancelled, battleSession.isAutoBattleEnabled else {
            cancelCardLift(for: card)
            return false
        }
        guard let request = activationRequest(for: card, battleSize: battleSize) else {
            cancelCardLift(for: card)
            return false
        }
        let didPlay = playCard(card, request: request)
        if !didPlay {
            cancelCardLift(for: card)
        }
        return didPlay
    }

    func playCard(_ card: BattleCard, request: CardActivationRequest) -> Bool {
        let outcome = battleSession.playCard(cardID: card.id, requiresLift: true)
        guard case .committed = outcome else { return false }
        if card.ability.dealsCombatDamage, let actorID = battleSession.combatantID(for: card.owner) {
            battleSession.publishAttackTelegraph(.swing, for: actorID)
        }
        castPresentation.append(request)
        return true
    }

    func cancelCardLift(for card: BattleCard) {
        battleSession.cancelCardCue(card)
    }

    private func activationRequest(
        for card: BattleCard,
        battleSize: CGSize,
    ) -> CardActivationRequest? {
        let hand = battleSession.hand
        guard let index = hand.firstIndex(where: { $0.id == card.id }) else { return nil }
        return CardActivationRequest.restingRequest(
            for: card,
            index: index,
            cardCount: hand.count,
            battleSize: battleSize,
            liftFraction: BattleMotion.tapLiftHeightFraction,
        )
    }
}
