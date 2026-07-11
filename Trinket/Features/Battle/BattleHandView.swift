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

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 38

    var body: some View {
        let ownerLabel = card.owner == .hero ? "Hero" : "Pet"
        artFace
            .frame(width: width, height: height)
            .clipShape(TrinketDesign.cardShape)
            .trinketCardSurface()
            .opacity(isPlayable ? 1 : 0.45)
            .rotationEffect(.degrees(isDragging ? 0 : restingRotation), anchor: .bottom)
            .offset(y: isDragging ? -dragOffset - 24 : height * 0.25 + restingOffsetY)
            .scaleEffect(isDragging ? 1.03 : 1)
            .mask(alignment: .top) {
                Rectangle()
                    .frame(height: isDragging ? height : height * 0.75)
            }
            .zIndex(isDragging ? 100 : 0)
            .animation(.smooth(duration: 0.16), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        guard isPlayable else { return }
                        dragOffset = max(0, -value.translation.height)
                    }
                    .onEnded { value in
                        let upwardDistance = -value.translation.height
                        let wasTap = abs(value.translation.width) < BattleHandLayout.dragMinimumDistance
                            && abs(value.translation.height) < BattleHandLayout.dragMinimumDistance
                        if wasTap {
                            onTap()
                        } else if isPlayable, upwardDistance >= playDragThreshold {
                            onPlay()
                        }
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            dragOffset = 0
                            isDragging = false
                        }
                    }
            )
            .accessibilityIdentifier(AccessibilityID.Battle.handCard(card.ability.id))
            .accessibilityLabel("\(card.ability.name), \(ownerLabel)")
            .accessibilityHint(isPlayable ? "Tap for details. Drag up to play." : "Cannot play now")
            .accessibilityAddTraits(isDragging ? [] : .isButton)
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
