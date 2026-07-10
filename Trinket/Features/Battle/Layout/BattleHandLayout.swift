import CoreGraphics

/// Fan layout metrics for the battle ability hand.
///
/// Keeps GeometryReader math out of the view layer while preserving the
/// overlapping 3:4 card fan (no first-party SwiftUI card-fan API).
enum BattleHandLayout {
    static let minCardWidth: CGFloat = 104
    static let maxCardWidth: CGFloat = 144
    static let aspectRatio: CGFloat = 4.0 / 3.0
    static let horizontalInset: CGFloat = 24
    static let overlapTrailingInset: CGFloat = 16
    static let maxOverlapRatio: CGFloat = 0.55
    static let maxVisibleCardsForWidth: Int = 6
    /// Drag-up distance required to play a card (1:1 with finger until release).
    static let playDragThreshold: CGFloat = 80
    static let dragMinimumDistance: CGFloat = 12

    struct Metrics: Equatable {
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let overlap: CGFloat
        let startX: CGFloat
    }

    static func metrics(containerWidth: CGFloat, cardCount: Int) -> Metrics {
        let count = max(cardCount, 1)
        let cardWidth = min(
            maxCardWidth,
            max(minCardWidth, (containerWidth - horizontalInset) / CGFloat(min(count, maxVisibleCardsForWidth)))
        )
        let cardHeight = cardWidth * aspectRatio
        let overlap: CGFloat = cardCount > 1
            ? min(
                cardWidth * maxOverlapRatio,
                (containerWidth - cardWidth - overlapTrailingInset) / CGFloat(cardCount - 1)
            )
            : 0
        let totalWidth = cardWidth + overlap * CGFloat(max(cardCount - 1, 0))
        let startX = (containerWidth - totalWidth) / 2
        return Metrics(
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            overlap: overlap,
            startX: startX
        )
    }

    static func cardOffsetX(index: Int, metrics: Metrics, containerWidth: CGFloat) -> CGFloat {
        metrics.startX + CGFloat(index) * metrics.overlap - containerWidth / 2 + metrics.cardWidth / 2
    }
}
