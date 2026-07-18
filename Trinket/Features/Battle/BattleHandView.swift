import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Fan pose captured at pickup so hand reflow cannot retarget a held card.
private struct HeldCardLayoutSnapshot: Equatable {
    var width: CGFloat
    var height: CGFloat
    var restingRotation: CGFloat
    var restingOffsetY: CGFloat
    var restingCenter: CGPoint
    var fanOffsetX: CGFloat
}

struct BattleHandView: View {
    let cards: [BattleCard]
    let isPlayable: (BattleCard) -> Bool
    let onTap: (BattleCard) -> Void
    let onPlay: (BattleCard, CardActivationRequest) -> Bool
    let hapticsEnabled: Bool
    let battleFrame: CGRect
    var configuration: BattleHandMotionConfiguration = .init()
    /// Lab / performance-harness forced drag. Observed per-card so translation
    /// ticks do not rebuild resting siblings.
    var forcedDrag: BattleForcedDragState?
    /// Fires when any hand card press/drag begins or ends (including tap-to-detail).
    var onCardInteractionChanged: ((Bool) -> Void)?
    /// Drag exceeded tap slop — start party attack wind-up for this card's owner.
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
            let cardIDs = cards.map(\.id)

            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let liveSnapshot = HeldCardLayoutSnapshot(
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
                            containerWidth: geometry.size.width
                        )
                    )
                    let snapshot = heldLayoutSnapshots[card.id] ?? liveSnapshot
                    let isHeld = activeCardID == card.id

                    // Observation boundary: only this slot watches forced drag.
                    // Parent hand body must not read translation or every sibling rebuilds.
                    BattleHandForcedDragSlot(
                        card: card,
                        isPlayable: isPlayable(card),
                        snapshot: snapshot,
                        index: index,
                        isHeld: isHeld,
                        cardIDs: cardIDs,
                        configuration: configuration,
                        hapticsEnabled: hapticsEnabled,
                        forcedDrag: forcedDrag,
                        onTap: { onTap(card) },
                        onPlay: { command in onPlay(card, command) },
                        onInteractionChanged: { isActive in
                            if isActive {
                                // Freeze the pose from the interaction start frame so later
                                // draws / reflow cannot rewrite the held card's fan.
                                if heldLayoutSnapshots[card.id] == nil {
                                    heldLayoutSnapshots[card.id] = liveSnapshot
                                }
                                activeCardID = card.id
                                onCardInteractionChanged?(true)
                            } else if activeCardID == card.id {
                                activeCardID = nil
                                heldLayoutSnapshots.removeValue(forKey: card.id)
                                onCardInteractionChanged?(false)
                            }
                        },
                        onAttackWindUp: { onAttackWindUp?(card) },
                        onAttackCancel: { onAttackCancel?(card) }
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }

        .accessibilityIdentifier(AccessibilityID.Battle.hand)
    }

    @State private var activeCardID: Int?
    @State private var heldLayoutSnapshots: [Int: HeldCardLayoutSnapshot] = [:]

    /// Production entry point (default motion configuration).
    init(
        cards: [BattleCard],
        isPlayable: @escaping (BattleCard) -> Bool,
        onTap: @escaping (BattleCard) -> Void,
        onPlay: @escaping (BattleCard, CardActivationRequest) -> Bool,
        hapticsEnabled: Bool,
        battleFrame: CGRect,
        onCardInteractionChanged: ((Bool) -> Void)? = nil,
        onAttackWindUp: ((BattleCard) -> Void)? = nil,
        onAttackCancel: ((BattleCard) -> Void)? = nil
    ) {
        self.init(
            cards: cards,
            isPlayable: isPlayable,
            onTap: onTap,
            onPlay: onPlay,
            hapticsEnabled: hapticsEnabled,
            battleFrame: battleFrame,
            configuration: .init(),
            forcedDrag: nil,
            onCardInteractionChanged: onCardInteractionChanged,
            onAttackWindUp: onAttackWindUp,
            onAttackCancel: onAttackCancel
        )
    }

    init(
        cards: [BattleCard],
        isPlayable: @escaping (BattleCard) -> Bool,
        onTap: @escaping (BattleCard) -> Void,
        onPlay: @escaping (BattleCard, CardActivationRequest) -> Bool,
        hapticsEnabled: Bool,
        battleFrame: CGRect,
        configuration: BattleHandMotionConfiguration,
        forcedDrag: BattleForcedDragState? = nil,
        onCardInteractionChanged: ((Bool) -> Void)? = nil,
        onAttackWindUp: ((BattleCard) -> Void)? = nil,
        onAttackCancel: ((BattleCard) -> Void)? = nil
    ) {
        self.cards = cards
        self.isPlayable = isPlayable
        self.onTap = onTap
        self.onPlay = onPlay
        self.hapticsEnabled = hapticsEnabled
        self.battleFrame = battleFrame
        self.configuration = configuration
        self.forcedDrag = forcedDrag
        self.onCardInteractionChanged = onCardInteractionChanged
        self.onAttackWindUp = onAttackWindUp
        self.onAttackCancel = onAttackCancel
    }
}

/// Per-card observation boundary for harness/lab forced drag. Sibling slots that
/// are not the target only track `cardID`; the target alone tracks `translation`.
private struct BattleHandForcedDragSlot: View {
    let card: BattleCard
    let isPlayable: Bool
    let snapshot: HeldCardLayoutSnapshot
    let index: Int
    let isHeld: Bool
    let cardIDs: [Int]
    let configuration: BattleHandMotionConfiguration
    let hapticsEnabled: Bool
    let forcedDrag: BattleForcedDragState?
    let onTap: () -> Void
    let onPlay: (CardActivationRequest) -> Bool
    let onInteractionChanged: (Bool) -> Void
    let onAttackWindUp: () -> Void
    let onAttackCancel: () -> Void

    private var forcedTranslation: CGSize? {
        guard let forcedDrag, forcedDrag.cardID == card.id else { return nil }
        return forcedDrag.translation
    }

    private var forcedPlayCommitGeneration: Int {
        guard let forcedDrag, forcedDrag.cardID == card.id else { return 0 }
        return forcedDrag.playCommitGeneration
    }

    var body: some View {
        let forced = forcedTranslation
        BattleAbilityCardView(
            card: card,
            isPlayable: isPlayable,
            width: snapshot.width,
            height: snapshot.height,
            restingRotation: snapshot.restingRotation,
            restingOffsetY: snapshot.restingOffsetY,
            configuration: configuration,
            restingCenter: snapshot.restingCenter,
            hapticsEnabled: hapticsEnabled,
            forcedDragTranslation: forced,
            forcedPlayCommitGeneration: forcedPlayCommitGeneration,
            onTap: onTap,
            onPlay: onPlay,
            onInteractionChanged: onInteractionChanged,
            onAttackWindUp: onAttackWindUp,
            onAttackCancel: onAttackCancel,
            onForcedPlayConsumed: { forcedDrag?.clear() }
        )
        .offset(x: snapshot.fanOffsetX)
        .zIndex(isHeld || forced != nil ? 100 : Double(index))
        .animation(isHeld || forced != nil ? nil : configuration.handReflow, value: cardIDs)
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
                .animation(
                    configuration.handReflow
                        .delay(Double(index) * configuration.cardDrawStagger)
                ),
                removal: .identity
            )
        )
    }
}
