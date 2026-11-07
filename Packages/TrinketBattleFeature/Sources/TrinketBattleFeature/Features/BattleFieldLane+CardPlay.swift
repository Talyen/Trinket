import BattleEngine
import SwiftUI

extension BattleFieldLane {
    var input: BattleViewInput {
        BattleViewInput(session: battleSession, presentation: presentation)
    }

    var autoBattleTaskID: String {
        "\(input.isCurrent)-\(battleSession.isAutoBattleEnabled)-\(configuration.id.uuidString)"
    }

    func playAutoBattleCard(_ card: BattleCard, handFrame: CGRect) -> Bool {
        guard input.isCurrent, !Task.isCancelled, battleSession.isAutoBattleEnabled,
              let request = activationRequest(for: card, handFrame: handFrame)
        else { return false }
        input.perform { $0.beginCardCue(card, mode: .pressPreview) }
        let didPlay = playCard(card, request: request)
        if !didPlay {
            cancelCardLift(for: card)
        }
        return didPlay
    }

    func playCard(_ card: BattleCard, request: CardActivationRequest) -> Bool {
        let outcome = input.perform { $0.playCard(cardID: card.id) }
        guard outcome == .committed else { return false }
        castPresentation.append(request, playback: presentation.cardPlayback)
        return true
    }

    func cancelCardLift(for card: BattleCard) {
        input.perform { $0.cancelCardCue(card) }
    }

    private func activationRequest(
        for card: BattleCard,
        handFrame: CGRect,
    ) -> CardActivationRequest? {
        let hand = presentation.hand
        guard let index = hand.firstIndex(where: { $0.id == card.id }) else { return nil }
        return CardActivationRequest.tapRequest(
            for: card,
            index: index,
            cardCount: hand.count,
            handFrame: handFrame,
            isPad: BattleHandLayout.usesPadSizing,
        )
    }
}
