import BattleEngine
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

#if DEBUG

@MainActor
struct BattlePerformanceScenarioDriver {
    let scenario: BattlePerformanceScenario
    let battleSession: BattleSession
    let battleSize: CGSize
    let castPresentation: BattleCastPresentationState

    func perform() -> String? {
        switch scenario {
        case .realCardPlay, .handDragCancel:
            nil
        case .engineHand:
            runEngineHand()
        case .engineFeedback:
            runEngineFeedback()
        case .turnTransition:
            runTurnTransition()
        case .combinedWorstCase:
            runCombinedWorstCase()
        }
    }

    private func runEngineHand() -> String? {
        guard let card = playableCard() else {
            return "no-playable-card"
        }
        return battleSession.performEngineCardForPerformance(cardID: card.id)
            ? nil
            : "engine-rejected"
    }

    private func runEngineFeedback() -> String? {
        guard let card = playableCard() else { return "no-playable-card" }
        let outcome = battleSession.playCard(cardID: card.id)
        return outcome.didCommit ? nil : "commit-rejected"
    }

    private func runTurnTransition() -> String? {
        battleSession.endTurn()
        return nil
    }

    private func runCombinedWorstCase() -> String? {
        guard let card = playableCard() else { return "no-playable-card" }
        if let combatantID = battleSession.combatantID(for: card.owner) {
            battleSession.publishAttackTelegraph(.windUp, for: combatantID)
        }
        let outcome = battleSession.playCard(cardID: card.id)
        guard outcome.didCommit else { return "commit-rejected" }
        if let combatantID = battleSession.combatantID(for: card.owner) {
            battleSession.publishAttackTelegraph(.swing, for: combatantID)
        }
        castPresentation.append(activationRequest(for: card))
        return nil
    }

    private func playableCard() -> BattleCard? {
        battleSession.hand.first(where: { battleSession.isCardPlayable($0) })
    }

    private func activationRequest(for card: BattleCard) -> CardActivationRequest {
        let hand = battleSession.hand
        let index = hand.firstIndex(where: { $0.id == card.id }) ?? 0
        return CardActivationRequest.restingRequest(
            for: card,
            index: index,
            cardCount: max(1, hand.count),
            battleSize: battleSize,
        )
    }
}
#endif
