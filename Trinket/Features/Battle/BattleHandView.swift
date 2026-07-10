import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct BattleHandView: View {
    let cards: [BattleCard]
    let isPlayable: (BattleCard) -> Bool
    let onTap: (BattleCard) -> Void
    let onPlay: (BattleCard) -> Void

    private let playDragThreshold: CGFloat = 80

    var body: some View {
        GeometryReader { geometry in
            let count = max(cards.count, 1)
            let cardWidth = min(144, max(104, (geometry.size.width - 24) / CGFloat(min(count, 6))))
            let cardHeight = cardWidth * 4.0 / 3.0
            let overlap = cards.count > 1
                ? min(cardWidth * 0.55, (geometry.size.width - cardWidth - 16) / CGFloat(cards.count - 1))
                : 0
            let totalWidth = cardWidth + overlap * CGFloat(max(cards.count - 1, 0))
            let startX = (geometry.size.width - totalWidth) / 2

            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    BattleAbilityCardView(
                        card: card,
                        isPlayable: isPlayable(card),
                        width: cardWidth,
                        height: cardHeight,
                        playDragThreshold: playDragThreshold,
                        onTap: { onTap(card) },
                        onPlay: { onPlay(card) }
                    )
                    .offset(x: startX + CGFloat(index) * overlap - geometry.size.width / 2 + cardWidth / 2)
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
    let playDragThreshold: CGFloat
    let onTap: () -> Void
    let onPlay: () -> Void

    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 38

    var body: some View {
        let ownerLabel = card.owner == .hero ? "Hero" : "Pet"
        artFace
            .frame(width: width, height: height)
            .clipShape(TrinketDesign.cardShape)
            .trinketCardSurface()
            .opacity(isPlayable ? 1 : 0.45)
            .offset(y: -dragOffset)
            .gesture(
                DragGesture(minimumDistance: 12)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        guard isPlayable else { return }
                        dragOffset = max(0, -value.translation.height)
                    }
                    .onEnded { value in
                        defer { dragOffset = 0 }
                        guard isPlayable else { return }
                        if -value.translation.height >= playDragThreshold {
                            onPlay()
                        }
                    }
            )
            .onTapGesture {
                onTap()
            }
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
