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
    static let coordinateSpaceName = "battleHand"

    let cards: [BattleCard]
    let isDetailPresented: Bool
    let isPlayable: (BattleCard) -> Bool
    let onInspect: (BattleCard) -> Void
    let onPlay: (BattleCard, CardActivationRequest) -> Bool
    let onPlayDenied: (BattleCard) -> Void
    let hapticsEnabled: Bool
    var onFrameChanged: ((CGRect) -> Void)?
    var onCardInteractionChanged: ((Bool) -> Void)?
    var onLift: ((BattleCard, BattleCardCuePresentationMode) -> Void)?
    var onLiftCancel: ((BattleCard) -> Void)?

    @State private var heldInteraction: HeldCardInteraction?

    init(
        cards: [BattleCard],
        isDetailPresented: Bool,
        isPlayable: @escaping (BattleCard) -> Bool,
        onInspect: @escaping (BattleCard) -> Void,
        onPlay: @escaping (BattleCard, CardActivationRequest) -> Bool,
        onPlayDenied: @escaping (BattleCard) -> Void,
        hapticsEnabled: Bool,
        onFrameChanged: ((CGRect) -> Void)? = nil,
        onCardInteractionChanged: ((Bool) -> Void)? = nil,
        onLift: ((BattleCard, BattleCardCuePresentationMode) -> Void)? = nil,
        onLiftCancel: ((BattleCard) -> Void)? = nil,
    ) {
        self.cards = cards
        self.isDetailPresented = isDetailPresented
        self.isPlayable = isPlayable
        self.onInspect = onInspect
        self.onPlay = onPlay
        self.onPlayDenied = onPlayDenied
        self.hapticsEnabled = hapticsEnabled
        self.onFrameChanged = onFrameChanged
        self.onCardInteractionChanged = onCardInteractionChanged
        self.onLift = onLift
        self.onLiftCancel = onLiftCancel
    }

    var body: some View {
        GeometryReader { geometry in
            let handFrame = geometry.frame(in: .named(BattleCoordinateSpace.field))
            let layout = BattleHandLayout.metrics(
                containerWidth: geometry.size.width,
                cardCount: cards.count,
            )
            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let liveSnapshot = liveSnapshot(
                        index: index,
                        layout: layout,
                        handFrame: handFrame,
                    )
                    let isHeld = heldInteraction?.cardID == card.id
                    let snapshot = isHeld ? (heldInteraction?.layout ?? liveSnapshot) : liveSnapshot

                    BattleAbilityCardView(
                        card: card,
                        isPlayable: isPlayable(card),
                        isDetailPresented: isDetailPresented,
                        width: snapshot.width,
                        height: snapshot.height,
                        restingRotation: snapshot.restingRotation,
                        restingOffsetY: snapshot.restingOffsetY,
                        restingCenter: snapshot.restingCenter,
                        interactionFrame: handFrame,
                        hapticsEnabled: hapticsEnabled,
                        onInspect: { onInspect(card) },
                        onPlay: { command in onPlay(card, command) },
                        onPlayDenied: { onPlayDenied(card) },
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
                        onLift: { mode in onLift?(card, mode) },
                        onLiftCancel: { onLiftCancel?(card) },
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
                            .combined(with: .scale(scale: BattleMotion.dealInsertScale))
                            .animation(BattleMotion.deal),
                            removal: .identity,
                        ),
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }
        .onGeometryChange(for: CGRect.self) { geometry in
            geometry.frame(in: .named(BattleCoordinateSpace.field))
        } action: { frame in
            onFrameChanged?(frame)
        }
        .coordinateSpace(name: Self.coordinateSpaceName)
        .transition(.identity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Battle.hand)
    }

    private func liveSnapshot(
        index: Int,
        layout: BattleHandLayout.Metrics,
        handFrame: CGRect,
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
                handFrame: handFrame,
            ),
            fanOffsetX: BattleHandLayout.cardOffsetX(
                index: index,
                metrics: layout,
                containerWidth: handFrame.width,
            ),
        )
    }
}
