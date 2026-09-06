import BattleEngine
import SwiftUI
import TrinketDesignSystem

extension BattleFieldLane {
    var autoBattleTaskID: String {
        "\(battleSession.isAutoBattleEnabled)-\(battleSession.activeBattle?.id.uuidString ?? "none")"
    }

    func playCardWithTapLift(_ card: BattleCard, battleSize: CGSize) async -> Bool {
        interactionState.suppressCombatantTaps = false
        interactionState.autoLiftCardID = card.id
        defer {
            if interactionState.autoLiftCardID == card.id {
                interactionState.autoLiftCardID = nil
            }
        }

        try? await Task.sleep(for: .seconds(BattleMotion.tapLiftPlayDelay))
        guard !Task.isCancelled, battleSession.isAutoBattleEnabled else {
            cancelPartyAttack(for: card)
            return false
        }
        guard let request = activationRequest(for: card, battleSize: battleSize) else {
            cancelPartyAttack(for: card)
            return false
        }
        let didPlay = playCard(card, request: request)
        if !didPlay {
            cancelPartyAttack(for: card)
        }
        return didPlay
    }

    func playCard(_ card: BattleCard, request: CardActivationRequest) -> Bool {
        let outcome = battleSession.playCard(cardID: card.id)
        guard case .committed = outcome else { return false }
        if let actorID = battleSession.combatantID(for: card.owner) {
            battleSession.publishAttackTelegraph(.swing, for: actorID)
        }
        castPresentation.append(request)
        return true
    }

    func cancelPartyAttack(for card: BattleCard) {
        guard let combatantID = battleSession.combatantID(for: card.owner) else { return }
        battleSession.publishAttackTelegraph(.cancel, for: combatantID)
    }

    private func activationRequest(
        for card: BattleCard,
        battleSize: CGSize,
    ) -> CardActivationRequest? {
        let hand = battleSession.hand
        guard let index = hand.firstIndex(where: { $0.id == card.id }) else { return nil }

        let metrics = BattleHandLayout.metrics(
            containerWidth: battleSize.width,
            cardCount: hand.count,
        )
        let restingCenter = BattleHandLayout.restingCenter(
            index: index,
            metrics: metrics,
            cardCount: hand.count,
            containerFrame: CGRect(origin: .zero, size: battleSize),
        )
        let center = CGPoint(
            x: restingCenter.x,
            y: restingCenter.y - metrics.cardHeight * BattleMotion.tapLiftHeightFraction,
        )

        return CardActivationRequest(
            artworkName: card.ability.artReference?.imageName,
            center: center,
            size: CGSize(width: metrics.cardWidth, height: metrics.cardHeight),
            rotation: BattleHandLayout.rotation(
                index: index,
                cardCount: hand.count,
            ) * .pi / 180,
            verticalTilt: 0,
            scale: 1,
            perspective: BattleMotion.cardPerspective,
            keywords: card.ability.presentationKeywords,
        )
    }
}
