import BattleEngine
import SwiftUI
import TrinketFeatureSupport

/// Runs the Auto Battle task at the presentation boundary, where it can create
/// the same card-cast request the hand uses without moving geometry into state.
struct BattleAutoPlayLane: View {
    let battleSession: BattleSession
    let battleSize: CGSize
    let castPresentation: BattleCastPresentationState
    let interactionState: BattleInteractionState
    let onPlay: (BattleCard, CardActivationRequest) -> Bool

    private var taskID: String {
        "\(battleSession.isAutoBattleEnabled)-\(battleSession.activeBattle?.id.uuidString ?? "none")"
    }

    var body: some View {
        EmptyView()
            .task(id: taskID) {
                await battleSession.driveAutoBattle(
                    isCardCastActive: { castPresentation.request != nil },
                    isManualInteractionActive: { interactionState.suppressCombatantTaps },
                    playCard: { card in
                        guard let request = activationRequest(for: card) else { return false }
                        return onPlay(card, request)
                    }
                )
            }
    }

    private func activationRequest(for card: BattleCard) -> CardActivationRequest? {
        let hand = battleSession.hand
        guard let index = hand.firstIndex(where: { $0.id == card.id }) else { return nil }

        let configuration = BattleHandMotionConfiguration()
        let metrics = BattleHandLayout.metrics(
            containerWidth: battleSize.width,
            cardCount: hand.count,
            configuration: configuration
        )
        let center = BattleHandLayout.restingCenter(
            index: index,
            metrics: metrics,
            cardCount: hand.count,
            containerFrame: CGRect(origin: .zero, size: battleSize),
            configuration: configuration
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
