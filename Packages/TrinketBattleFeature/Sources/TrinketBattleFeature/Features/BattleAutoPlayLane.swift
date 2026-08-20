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
                // New driver (new battle or Auto toggled on): drop a leftover
                // tap-suppress flag from a cancelled gesture. A live drag after
                // this point sets the flag again via the hand.
                interactionState.suppressCombatantTaps = false
                await battleSession.driveAutoBattle(
                    isCardCastActive: { castPresentation.request != nil },
                    isManualInteractionActive: { interactionState.blocksCombatantTaps },
                    playCard: { card in
                        await playCardWithTapLift(card)
                    }
                )
            }
    }

    private func playCardWithTapLift(_ card: BattleCard) async -> Bool {
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
            cancelAttack(for: card)
            return false
        }
        guard let request = activationRequest(for: card, configuration: configuration) else {
            cancelAttack(for: card)
            return false
        }
        let didPlay = onPlay(card, request)
        if !didPlay {
            cancelAttack(for: card)
        }
        return didPlay
    }

    private func cancelAttack(for card: BattleCard) {
        guard let combatantID = battleSession.combatantID(for: card.owner) else { return }
        battleSession.cancelAttack(for: combatantID)
    }

    private func activationRequest(
        for card: BattleCard,
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
