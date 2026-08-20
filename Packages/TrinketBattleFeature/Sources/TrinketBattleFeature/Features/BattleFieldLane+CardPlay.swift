import BattleEngine
import SwiftUI

extension BattleFieldLane {
    var autoBattleTaskID: String {
        "\(battleSession.isAutoBattleEnabled)-\(battleSession.activeBattle?.id.uuidString ?? "none")"
    }

    func playCardWithTapLift(_ card: BattleCard, battleSize: CGSize) async -> Bool {
        let configuration = BattleHandMotionConfiguration()
        interactionState.suppressCombatantTaps = false
        interactionState.autoLiftCardID = card.id
        defer {
            if interactionState.autoLiftCardID == card.id {
                interactionState.autoLiftCardID = nil
            }
        }

        try? await Task.sleep(for: .seconds(configuration.tapLiftPlayDelay))
        guard !Task.isCancelled, battleSession.isAutoBattleEnabled else {
            cancelPartyAttack(for: card)
            return false
        }
        guard let request = activationRequest(
            for: card,
            battleSize: battleSize,
            configuration: configuration
        ) else {
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
            battleSession.commitAttackSwing(for: actorID)
        }
        castPresentation.append(request)
        return true
    }

    func cancelPartyAttack(for card: BattleCard) {
        guard let combatantID = battleSession.combatantID(for: card.owner) else { return }
        battleSession.cancelAttack(for: combatantID)
    }

    private func activationRequest(
        for card: BattleCard,
        battleSize: CGSize,
        configuration: BattleHandMotionConfiguration
    ) -> CardActivationRequest? {
        let hand = battleSession.hand
        guard let index = hand.firstIndex(where: { $0.id == card.id }) else { return nil }

        let metrics = BattleHandLayout.metrics(
            containerWidth: battleSize.width,
            cardCount: hand.count,
            configuration: configuration
        )
        let restingCenter = BattleHandLayout.restingCenter(
            index: index,
            metrics: metrics,
            cardCount: hand.count,
            containerFrame: CGRect(origin: .zero, size: battleSize),
            configuration: configuration
        )
        let center = CGPoint(
            x: restingCenter.x,
            y: restingCenter.y - metrics.cardHeight * configuration.tapLiftHeight
        )

        return CardActivationRequest(
            artworkName: card.ability.artReference?.imageName,
            center: center,
            size: CGSize(width: metrics.cardWidth, height: metrics.cardHeight),
            rotation: BattleHandLayout.rotation(
                index: index,
                cardCount: hand.count,
                fanAngleStep: configuration.fanAngleStep
            ) * .pi / 180,
            verticalTilt: 0,
            scale: 1,
            perspective: configuration.perspective,
            keywords: card.ability.keywords
        )
    }
}
