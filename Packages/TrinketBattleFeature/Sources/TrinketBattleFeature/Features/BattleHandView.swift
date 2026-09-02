import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

private struct HeldCardLayoutSnapshot: Equatable {
    var width: CGFloat
    var height: CGFloat
    var restingRotation: CGFloat
    var restingOffsetY: CGFloat
    var restingCenter: CGPoint
    var fanOffsetX: CGFloat
}

private struct HeldCardInteraction: Equatable {
    let cardID: Int
    let layout: HeldCardLayoutSnapshot
}

struct BattleHandView: View {
    let cards: [BattleCard]
    let isPlayable: (BattleCard) -> Bool
    let onInspect: (BattleCard) -> Void
    let onPlay: (BattleCard, CardActivationRequest) -> Bool
    let onPlayDenied: () -> Void
    let hapticsEnabled: Bool
    let battleFrame: CGRect
    var autoLiftCardID: Int?
    var onCardInteractionChanged: ((Bool) -> Void)?
    var onAttackWindUp: ((BattleCard) -> Void)?
    var onAttackCancel: ((BattleCard) -> Void)?

    @State private var heldInteraction: HeldCardInteraction?

    init(
        cards: [BattleCard],
        isPlayable: @escaping (BattleCard) -> Bool,
        onInspect: @escaping (BattleCard) -> Void,
        onPlay: @escaping (BattleCard, CardActivationRequest) -> Bool,
        onPlayDenied: @escaping () -> Void,
        hapticsEnabled: Bool,
        battleFrame: CGRect,
        autoLiftCardID: Int? = nil,
        onCardInteractionChanged: ((Bool) -> Void)? = nil,
        onAttackWindUp: ((BattleCard) -> Void)? = nil,
        onAttackCancel: ((BattleCard) -> Void)? = nil,
    ) {
        self.cards = cards
        self.isPlayable = isPlayable
        self.onInspect = onInspect
        self.onPlay = onPlay
        self.onPlayDenied = onPlayDenied
        self.hapticsEnabled = hapticsEnabled
        self.battleFrame = battleFrame
        self.autoLiftCardID = autoLiftCardID
        self.onCardInteractionChanged = onCardInteractionChanged
        self.onAttackWindUp = onAttackWindUp
        self.onAttackCancel = onAttackCancel
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = BattleHandLayout.metrics(
                containerWidth: geometry.size.width,
                cardCount: cards.count,
            )
            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let liveSnapshot = liveSnapshot(
                        index: index,
                        layout: layout,
                        containerWidth: geometry.size.width,
                    )
                    let isHeld = heldInteraction?.cardID == card.id
                    let snapshot = isHeld ? (heldInteraction?.layout ?? liveSnapshot) : liveSnapshot

                    BattleAbilityCardView(
                        card: card,
                        isPlayable: isPlayable(card),
                        width: snapshot.width,
                        height: snapshot.height,
                        restingRotation: snapshot.restingRotation,
                        restingOffsetY: snapshot.restingOffsetY,
                        restingCenter: snapshot.restingCenter,
                        hapticsEnabled: hapticsEnabled,
                        autoLiftCardID: autoLiftCardID,
                        onInspect: { onInspect(card) },
                        onPlay: { command in onPlay(card, command) },
                        onPlayDenied: onPlayDenied,
                        onInteractionChanged: { isActive in
                            if isActive {
                                if heldInteraction?.cardID != card.id {
                                    heldInteraction = HeldCardInteraction(
                                        cardID: card.id,
                                        layout: liveSnapshot,
                                    )
                                }
                                onCardInteractionChanged?(true)
                            } else if heldInteraction?.cardID == card.id {
                                heldInteraction = nil
                                onCardInteractionChanged?(false)
                            }
                        },
                        onAttackWindUp: { onAttackWindUp?(card) },
                        onAttackCancel: { onAttackCancel?(card) },
                    )
                    .offset(x: snapshot.fanOffsetX)
                    .zIndex(isHeld ? 100 : Double(index))
                    .allowsHitTesting(true)
                    .animation(isHeld ? nil : BattleMotion.handReflow, value: liveSnapshot)
                    .transition(
                        .asymmetric(
                            insertion: .offset(
                                x: card.owner == .hero
                                    ? -BattleMotion.dealInsertOffset
                                    : BattleMotion.dealInsertOffset,
                                y: BattleMotion.dealInsertOffset,
                            )
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: BattleMotion.dealInsertScale))
                            .animation(BattleMotion.deal),
                            removal: .identity,
                        ),
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }

        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Battle.hand)
    }

    private func liveSnapshot(
        index: Int,
        layout: BattleHandLayout.Metrics,
        containerWidth: CGFloat,
    ) -> HeldCardLayoutSnapshot {
        HeldCardLayoutSnapshot(
            width: layout.cardWidth,
            height: layout.cardHeight,
            restingRotation: BattleHandLayout.rotation(
                index: index,
                cardCount: cards.count,
            ),
            restingOffsetY: BattleHandLayout.restingOffsetY(
                index: index,
                cardCount: cards.count,
            ),
            restingCenter: BattleHandLayout.restingCenter(
                index: index,
                metrics: layout,
                cardCount: cards.count,
                containerFrame: battleFrame,
            ),
            fanOffsetX: BattleHandLayout.cardOffsetX(
                index: index,
                metrics: layout,
                containerWidth: containerWidth,
            ),
        )
    }
}
