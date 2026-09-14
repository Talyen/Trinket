import BattleEngine
import SwiftUI

extension BattleFieldLane {
    var autoBattleTaskID: String {
        "\(battleSession.isAutoBattleEnabled)-\(battleSession.activeBattle?.id.uuidString ?? "none")"
    }

    func playAutoBattleCard(_ card: BattleCard, battleSize: CGSize) -> Bool {
        guard !Task.isCancelled, battleSession.isAutoBattleEnabled,
              let request = activationRequest(for: card, battleSize: battleSize)
        else { return false }
        battleSession.beginCardCue(card, mode: .tapCommit)
        let didPlay = playCard(card, request: request, isAutomatic: true)
        if !didPlay {
            cancelCardLift(for: card)
        }
        return didPlay
    }

    func playCard(_ card: BattleCard, request: CardActivationRequest, isAutomatic: Bool = false) -> Bool {
        let outcome = battleSession.playCard(cardID: card.id, isAutomatic: isAutomatic)
        guard case .committed = outcome else { return false }
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
        )
    }
}
