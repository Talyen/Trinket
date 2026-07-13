import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct BattleHandView: View {
    let cards: [BattleCard]
    let isPlayable: (BattleCard) -> Bool
    let onTap: (BattleCard) -> Void
    let onPlay: (BattleCard, CardActivationRequest) -> Bool
    let hapticsEnabled: Bool
    let battleFrame: CGRect

    var body: some View {
        GeometryReader { geometry in
            let layout = BattleHandLayout.metrics(
                containerWidth: geometry.size.width,
                cardCount: cards.count
            )

            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    BattleAbilityCardView(
                        card: card,
                        isPlayable: isPlayable(card),
                        width: layout.cardWidth,
                        height: layout.cardHeight,
                        restingRotation: BattleHandLayout.rotation(index: index, cardCount: cards.count),
                        restingOffsetY: BattleHandLayout.restingOffsetY(index: index, cardCount: cards.count),
                        playDragThreshold: BattleHandLayout.playDragThreshold,
                        restingCenter: BattleHandLayout.restingCenter(
                            index: index,
                            metrics: layout,
                            cardCount: cards.count,
                            containerFrame: battleFrame
                        ),
                        hapticsEnabled: hapticsEnabled,
                        onTap: { onTap(card) },
                        onPlay: { command in onPlay(card, command) },
                        onInteractionChanged: { isActive in
                            activeCardID = isActive ? card.id : (activeCardID == card.id ? nil : activeCardID)
                        }
                    )
                    .offset(
                        x: BattleHandLayout.cardOffsetX(
                            index: index,
                            metrics: layout,
                            containerWidth: geometry.size.width
                        )
                    )
                    .zIndex(activeCardID == card.id ? 100 : Double(index))
                    .transition(
                        .asymmetric(
                            insertion: .offset(
                                x: card.owner == .hero ? -64 : 64,
                                y: 78
                            )
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.88))
                            .animation(
                                TrinketMotion.Battle.handReflow
                                    .delay(Double(index) * TrinketMotion.Battle.cardDrawStagger)
                            ),
                            removal: .identity
                        )
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            .animation(TrinketMotion.Battle.handReflow, value: cards.map(\.id))
        }

        .accessibilityIdentifier(AccessibilityID.Battle.hand)
    }

    @State private var activeCardID: Int?

    init(
        cards: [BattleCard],
        isPlayable: @escaping (BattleCard) -> Bool,
        onTap: @escaping (BattleCard) -> Void,
        onPlay: @escaping (BattleCard, CardActivationRequest) -> Bool,
        hapticsEnabled: Bool,
        battleFrame: CGRect
    ) {
        self.cards = cards
        self.isPlayable = isPlayable
        self.onTap = onTap
        self.onPlay = onPlay
        self.hapticsEnabled = hapticsEnabled
        self.battleFrame = battleFrame
    }
}

struct BattleAbilityCardView: View {
    let card: BattleCard
    let isPlayable: Bool
    let width: CGFloat
    let height: CGFloat
    let restingRotation: CGFloat
    let restingOffsetY: CGFloat
    let playDragThreshold: CGFloat
    let restingCenter: CGPoint
    let hapticsEnabled: Bool
    let onTap: () -> Void
    let onPlay: (CardActivationRequest) -> Bool
    let onInteractionChanged: (Bool) -> Void

    @State private var dragTranslation: CGSize = .zero
    @State private var predictedEndTranslation: CGSize = .zero
    @State private var isDragging = false
    @State private var isPlayArmed = false
    @State private var playArmFeedbackToken = 0
    @State private var denyFeedbackToken = 0
    @State private var didAnnounceDeny = false
    var body: some View {
        BattleAbilityCardFace(artworkName: card.ability.artReference?.imageName)
            .frame(width: width, height: height)
            .opacity(isPlayable ? 1 : 0.45)
            .rotationEffect(.degrees(activeRotation), anchor: .bottom)
            .rotation3DEffect(
                .degrees(isDragging ? verticalTilt : 0),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: 0.35
            )
            .offset(activeOffset)
            .scaleEffect(x: activeScale.width, y: activeScale.height)
            .shadow(
                color: isDragging ? TrinketDesign.Colors.Overlay.dragShadow : .clear,
                radius: isDragging ? TrinketMotion.Battle.cardHeldShadowRadius : 0,
                y: isDragging ? TrinketMotion.Battle.cardHeldShadowY : 0
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(updateDrag)
                    .onEnded(endDrag)
            )
            .trinketSensoryFeedback(
                .selection,
                trigger: playArmFeedbackToken,
                enabled: hapticsEnabled
            )
            .trinketSensoryFeedback(
                .warning,
                trigger: denyFeedbackToken,
                enabled: hapticsEnabled
            )
            .onDisappear {
                onInteractionChanged(false)
            }
            .accessibilityIdentifier(AccessibilityID.Battle.handCard(card.ability.id))
    }

    private var activeOffset: CGSize {
        let resting = restingTranslation
        return CGSize(
            width: resting.width + (isDragging ? dragTranslation.width : 0),
            height: resting.height + (isDragging ? dragTranslation.height : 0)
        )
    }

    private var restingTranslation: CGSize {
        CGSize(width: 0, height: height * 0.25 + restingOffsetY)
    }

    private var activeRotation: Double {
        guard isDragging else { return restingRotation }
        return restingRotation + BattleHandLayout.heldTilt(
            translation: dragTranslation,
            predictedEndTranslation: predictedEndTranslation,
            cardWidth: width,
            maximumDegrees: TrinketMotion.Battle.cardMaximumTiltDegrees * 0.45
        )
    }

    private var verticalTilt: Double {
        min(max(Double(-dragTranslation.height / height) * 4, -4), 4)
    }

    private var heldScale: CGSize {
        guard isDragging else { return CGSize(width: 1, height: 1) }
        let base = TrinketMotion.Battle.cardHeldScale
        return CGSize(width: base, height: base)
    }

    private var activeScale: CGSize {
        heldScale
    }

    private func updateDrag(_ value: DragGesture.Value) {
        if !isDragging {
            withAnimation(TrinketMotion.Battle.cardPress) {
                isDragging = true
            }
            onInteractionChanged(true)
        }
        dragTranslation = BattleHandLayout.presentationTranslation(
            value.translation,
            isPlayable: isPlayable,
            threshold: playDragThreshold
        )
        predictedEndTranslation = value.predictedEndTranslation

        let armed = BattleHandLayout.shouldRemainPlayArmed(
            translation: value.translation,
            isPlayable: isPlayable,
            threshold: playDragThreshold,
            currentlyArmed: isPlayArmed
        )
        if armed != isPlayArmed {
            if armed {
                playArmFeedbackToken &+= 1
            }
            withAnimation(TrinketMotion.Battle.cardLift) {
                isPlayArmed = armed
            }
        }

        if !isPlayable {
            let release = value.predictedEndTranslation.height < value.translation.height
                ? value.predictedEndTranslation
                : value.translation
            let crossedDenyThreshold = -release.height >= playDragThreshold
                && -release.height > abs(release.width)
            if crossedDenyThreshold, !didAnnounceDeny {
                didAnnounceDeny = true
                denyFeedbackToken &+= 1
            } else if !crossedDenyThreshold {
                didAnnounceDeny = false
            }
        }
    }

    private func endDrag(_ value: DragGesture.Value) {
        let isTap = abs(value.translation.width) < BattleHandLayout.dragMinimumDistance
            && abs(value.translation.height) < BattleHandLayout.dragMinimumDistance
        if isTap {
            onTap()
            returnDrag()
            return
        }

        let shouldPlay = BattleHandLayout.shouldPlay(
            translation: value.translation,
            predictedEndTranslation: value.predictedEndTranslation,
            isPlayable: isPlayable,
            threshold: playDragThreshold
        )
        if shouldPlay {
            beginPlay()
            return
        }
        returnDrag()
    }

    private func returnDrag() {
        withAnimation(
            TrinketMotion.Battle.cardReturn
        ) {
            dragTranslation = .zero
            predictedEndTranslation = .zero
            isPlayArmed = false
            isDragging = false
        }
        onInteractionChanged(false)
    }

    private func beginPlay() {
        let request = CardActivationRequest(
            artworkName: card.ability.artReference?.imageName,
            center: BattleHandLayout.releaseCenter(
                restingCenter: restingCenter,
                dragTranslation: dragTranslation
            ),
            size: CGSize(width: width, height: height),
            rotation: CGFloat(activeRotation * .pi / 180),
            verticalTilt: CGFloat(verticalTilt),
            scale: heldScale.width,
            keywords: card.ability.keywords
        )
        let didPlay = onPlay(request)
        if didPlay {
            onInteractionChanged(false)
            return
        }
        returnDrag()
    }
}

struct BattleAbilityCardFace: View {
    let artworkName: String?

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 38

    var body: some View {
        Group {
            if let artworkName {
                Image(artworkName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.18)
                    Image(systemName: TrinketDesign.CardPlaceholderStyle.ability.symbolName)
                        .font(.system(size: placeholderIconSize, weight: .semibold))
                        .foregroundStyle(TrinketDesign.CardPlaceholderStyle.ability.color)
                }
            }
        }
        .clipShape(TrinketDesign.cardShape)
        .trinketCardSurface()
    }
}
