import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct BattleHandView: View {
    let cards: [BattleCard]
    let isPlayable: (BattleCard) -> Bool
    let onTap: (BattleCard) -> Void
    let onPlay: (BattleCard) -> Void

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
                        onTap: { onTap(card) },
                        onPlay: { onPlay(card) }
                    )
                    .offset(
                        x: BattleHandLayout.cardOffsetX(
                            index: index,
                            metrics: layout,
                            containerWidth: geometry.size.width
                        )
                    )
                    .zIndex(Double(index))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Battle.hand)
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
    let onTap: () -> Void
    let onPlay: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragTranslation: CGSize = .zero
    @State private var predictedEndTranslation: CGSize = .zero
    @State private var isDragging = false
    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 38

    var body: some View {
        let ownerLabel = card.owner == .hero ? "Hero" : "Pet"
        artFace
            .frame(width: width, height: height)
            .clipShape(TrinketDesign.cardShape)
            .trinketCardSurface()
            .opacity(isPlayable ? 1 : 0.45)
            .rotationEffect(.degrees(activeRotation), anchor: isDragging ? .center : .bottom)
            .rotation3DEffect(
                .degrees(isDragging && !reduceMotion ? verticalTilt : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.35
            )
            .offset(activeOffset)
            .scaleEffect(x: heldScale.width, y: heldScale.height)
            .shadow(
                color: .black.opacity(isDragging ? 0.3 : 0),
                radius: isDragging ? TrinketMotion.Battle.cardHeldShadowRadius : 0,
                y: isDragging ? TrinketMotion.Battle.cardHeldShadowY : 0
            )
            .zIndex(isDragging ? 100 : 0)
            .gesture(
                TapGesture()
                    .onEnded { onTap() }
                    .exclusively(
                        before: DragGesture(minimumDistance: BattleHandLayout.dragMinimumDistance)
                            .onChanged(updateDrag)
                            .onEnded(endDrag)
                    )
            )
            .accessibilityIdentifier(AccessibilityID.Battle.handCard(card.ability.id))
            .accessibilityLabel("\(card.ability.name), \(ownerLabel)")
            .accessibilityHint(isPlayable ? "Tap for details. Drag up to play." : "Cannot play now")
            .accessibilityAddTraits(isDragging ? [] : .isButton)
    }

    private var activeOffset: CGSize {
        if isDragging {
            dragTranslation
        } else {
            CGSize(width: 0, height: height * 0.25 + restingOffsetY)
        }
    }

    private var activeRotation: Double {
        guard isDragging else { return restingRotation }
        guard !reduceMotion else { return 0 }
        return BattleHandLayout.heldTilt(
            translation: dragTranslation,
            predictedEndTranslation: predictedEndTranslation,
            cardWidth: width,
            maximumDegrees: TrinketMotion.Battle.cardMaximumTiltDegrees
        )
    }

    private var verticalTilt: Double {
        min(max(Double(-dragTranslation.height / height) * 4, -4), 4)
    }

    private var heldScale: CGSize {
        guard isDragging, !reduceMotion else { return CGSize(width: 1, height: 1) }
        let base = TrinketMotion.Battle.cardHeldScale
        let distance = hypot(dragTranslation.width, dragTranslation.height)
        let stretch = min(distance / 400, 1) * TrinketMotion.Battle.cardMaximumStretch
        if abs(dragTranslation.width) > abs(dragTranslation.height) {
            return CGSize(width: base + stretch, height: base - stretch)
        }
        return CGSize(width: base - stretch, height: base + stretch)
    }

    private func updateDrag(_ value: DragGesture.Value) {
        if !isDragging {
            withAnimation(reduceMotion ? nil : TrinketMotion.Battle.cardLift) {
                isDragging = true
            }
        }
        dragTranslation = value.translation
        predictedEndTranslation = value.predictedEndTranslation
    }

    private func endDrag(_ value: DragGesture.Value) {
        let shouldPlay = BattleHandLayout.shouldPlay(
            translation: value.translation,
            predictedEndTranslation: value.predictedEndTranslation,
            isPlayable: isPlayable,
            threshold: playDragThreshold
        )
        if shouldPlay {
            onPlay()
        }
        withAnimation(
            reduceMotion
                ? TrinketMotion.Battle.cardReturnReducedMotion
                : TrinketMotion.Battle.cardReturn
        ) {
            dragTranslation = .zero
            predictedEndTranslation = .zero
            isDragging = false
        }
    }

    @ViewBuilder
    private var artFace: some View {
        if let artRef = card.ability.artReference {
            Image(artRef.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityHidden(true)
        } else {
            ZStack {
                TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.18)
                Image(systemName: TrinketDesign.CardPlaceholderStyle.ability.symbolName)
                    .font(.system(size: placeholderIconSize, weight: .semibold))
                    .foregroundStyle(TrinketDesign.CardPlaceholderStyle.ability.color)
                    .accessibilityHidden(true)
            }
        }
    }
}
