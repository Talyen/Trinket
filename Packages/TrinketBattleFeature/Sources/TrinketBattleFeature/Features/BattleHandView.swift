import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Fan pose captured at pickup so hand reflow cannot retarget a held card.
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
    /// Triggered Stun/Freeze keyword for party owners skipping this turn.
    var ownerControlSkipKeywords: [BattleParticipant: Keyword] = [:]
    let onInspect: (BattleCard) -> Void
    let onPlay: (BattleCard, CardActivationRequest) -> Bool
    let hapticsEnabled: Bool
    let battleFrame: CGRect
    var configuration: BattleHandMotionConfiguration = .init()
    /// When set, the matching hand card mirrors Auto Battle's tap-lift rise.
    var autoLiftCardID: Int?
    /// Fires when any hand card press/drag begins or ends (including long-press detail).
    var onCardInteractionChanged: ((Bool) -> Void)?
    /// Drag exceeded tap slop or tap-lift began — start party attack wind-up.
    var onAttackWindUp: ((BattleCard) -> Void)?
    /// Card returned to hand without casting — cancel wind-up for this card's owner.
    var onAttackCancel: ((BattleCard) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let layout = BattleHandLayout.metrics(
                containerWidth: geometry.size.width,
                cardCount: cards.count,
                configuration: configuration
            )
            let liveSnapshots = cards.indices.map { index in
                liveSnapshot(
                    index: index,
                    layout: layout,
                    containerWidth: geometry.size.width
                )
            }
            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let liveSnapshot = liveSnapshots[index]
                    let isHeld = heldInteraction?.cardID == card.id
                    let snapshot = isHeld ? (heldInteraction?.layout ?? liveSnapshot) : liveSnapshot

                    BattleAbilityCardView(
                        card: card,
                        isPlayable: isPlayable(card),
                        controlSkipKeyword: ownerControlSkipKeywords[card.owner],
                        width: snapshot.width,
                        height: snapshot.height,
                        restingRotation: snapshot.restingRotation,
                        restingOffsetY: snapshot.restingOffsetY,
                        configuration: configuration,
                        restingCenter: snapshot.restingCenter,
                        hapticsEnabled: hapticsEnabled,
                        autoLiftCardID: autoLiftCardID,
                        onInspect: { onInspect(card) },
                        onPlay: { command in onPlay(card, command) },
                        onInteractionChanged: { isActive in
                            if isActive {
                                // Freeze the pose from the interaction start frame so later
                                // draws / reflow cannot rewrite the held card's fan.
                                if heldInteraction?.cardID != card.id {
                                    heldInteraction = HeldCardInteraction(
                                        cardID: card.id,
                                        layout: liveSnapshot
                                    )
                                }
                                onCardInteractionChanged?(true)
                            } else if heldInteraction?.cardID == card.id {
                                heldInteraction = nil
                                onCardInteractionChanged?(false)
                            }
                        },
                        onAttackWindUp: { onAttackWindUp?(card) },
                        onAttackCancel: { onAttackCancel?(card) }
                    )
                    .offset(x: snapshot.fanOffsetX)
                    .zIndex(isHeld ? 100 : Double(index))
                    .animation(isHeld ? nil : configuration.handReflow, value: liveSnapshot)
                    .transition(
                        .asymmetric(
                            insertion: .offset(
                                x: card.owner == .hero
                                    ? -configuration.dealInsertOffsetX
                                    : configuration.dealInsertOffsetX,
                                y: configuration.dealInsertOffsetY
                            )
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: configuration.dealInsertScale))
                            .animation(configuration.deal),
                            removal: .identity
                        )
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }

        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Battle.hand)
    }

    @State private var heldInteraction: HeldCardInteraction?

    /// Production entry point (default motion configuration).
    init(
        cards: [BattleCard],
        isPlayable: @escaping (BattleCard) -> Bool,
        ownerControlSkipKeywords: [BattleParticipant: Keyword] = [:],
        onInspect: @escaping (BattleCard) -> Void,
        onPlay: @escaping (BattleCard, CardActivationRequest) -> Bool,
        hapticsEnabled: Bool,
        battleFrame: CGRect,
        autoLiftCardID: Int? = nil,
        onCardInteractionChanged: ((Bool) -> Void)? = nil,
        onAttackWindUp: ((BattleCard) -> Void)? = nil,
        onAttackCancel: ((BattleCard) -> Void)? = nil
    ) {
        self.init(
            cards: cards,
            isPlayable: isPlayable,
            ownerControlSkipKeywords: ownerControlSkipKeywords,
            onInspect: onInspect,
            onPlay: onPlay,
            hapticsEnabled: hapticsEnabled,
            battleFrame: battleFrame,
            configuration: .init(),
            autoLiftCardID: autoLiftCardID,
            onCardInteractionChanged: onCardInteractionChanged,
            onAttackWindUp: onAttackWindUp,
            onAttackCancel: onAttackCancel
        )
    }

    init(
        cards: [BattleCard],
        isPlayable: @escaping (BattleCard) -> Bool,
        ownerControlSkipKeywords: [BattleParticipant: Keyword] = [:],
        onInspect: @escaping (BattleCard) -> Void,
        onPlay: @escaping (BattleCard, CardActivationRequest) -> Bool,
        hapticsEnabled: Bool,
        battleFrame: CGRect,
        configuration: BattleHandMotionConfiguration,
        autoLiftCardID: Int? = nil,
        onCardInteractionChanged: ((Bool) -> Void)? = nil,
        onAttackWindUp: ((BattleCard) -> Void)? = nil,
        onAttackCancel: ((BattleCard) -> Void)? = nil
    ) {
        self.cards = cards
        self.isPlayable = isPlayable
        self.ownerControlSkipKeywords = ownerControlSkipKeywords
        self.onInspect = onInspect
        self.onPlay = onPlay
        self.hapticsEnabled = hapticsEnabled
        self.battleFrame = battleFrame
        self.configuration = configuration
        self.autoLiftCardID = autoLiftCardID
        self.onCardInteractionChanged = onCardInteractionChanged
        self.onAttackWindUp = onAttackWindUp
        self.onAttackCancel = onAttackCancel
    }

    private func liveSnapshot(
        index: Int,
        layout: BattleHandLayout.Metrics,
        containerWidth: CGFloat
    ) -> HeldCardLayoutSnapshot {
        HeldCardLayoutSnapshot(
            width: layout.cardWidth,
            height: layout.cardHeight,
            restingRotation: BattleHandLayout.rotation(
                index: index,
                cardCount: cards.count,
                fanAngleStep: configuration.fanAngleStep
            ),
            restingOffsetY: BattleHandLayout.restingOffsetY(
                index: index,
                cardCount: cards.count,
                fanLiftStep: configuration.fanLiftStep
            ),
            restingCenter: BattleHandLayout.restingCenter(
                index: index,
                metrics: layout,
                cardCount: cards.count,
                containerFrame: battleFrame,
                configuration: configuration
            ),
            fanOffsetX: BattleHandLayout.cardOffsetX(
                index: index,
                metrics: layout,
                containerWidth: containerWidth
            )
        )
    }
}
