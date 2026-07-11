import CoreGraphics

/// Fan layout metrics for the battle ability hand.
///
/// Keeps GeometryReader math out of the view layer while preserving the
/// overlapping 3:4 card fan (no first-party SwiftUI card-fan API).
enum BattleHandLayout {
    static let minCardWidth: CGFloat = 156
    static let maxCardWidth: CGFloat = 184
    static let aspectRatio: CGFloat = 4.0 / 3.0
    static let widthRatio: CGFloat = 0.43
    static let horizontalInset: CGFloat = 8
    static let maxOverlapRatio: CGFloat = 0.38
    /// Drag-up distance required to play a card (1:1 with finger until release).
    static let playDragThreshold: CGFloat = 80
    static let dragMinimumDistance: CGFloat = 12

    struct Metrics: Equatable {
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let overlap: CGFloat
        let startX: CGFloat
        let clippedHeight: CGFloat
    }

    static func metrics(containerWidth: CGFloat, cardCount: Int) -> Metrics {
        let count = max(cardCount, 1)
        let cardWidth = min(maxCardWidth, max(minCardWidth, containerWidth * widthRatio))
        let cardHeight = cardWidth * aspectRatio
        let overlap: CGFloat = cardCount > 1
            ? min(
                cardWidth * maxOverlapRatio,
                (containerWidth - cardWidth - horizontalInset * 2) / CGFloat(cardCount - 1)
            )
            : 0
        let totalWidth = cardWidth + overlap * CGFloat(max(cardCount - 1, 0))
        let startX = (containerWidth - totalWidth) / 2
        return Metrics(
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            overlap: overlap,
            startX: startX,
            clippedHeight: cardHeight * 0.75
        )
    }

    static func cardOffsetX(index: Int, metrics: Metrics, containerWidth: CGFloat) -> CGFloat {
        metrics.startX + CGFloat(index) * metrics.overlap - containerWidth / 2 + metrics.cardWidth / 2
    }

    static func rotation(index: Int, cardCount: Int) -> CGFloat {
        guard cardCount > 1 else { return 0 }
        return (CGFloat(index) - CGFloat(cardCount - 1) / 2) * 6
    }

    static func restingOffsetY(index: Int, cardCount: Int) -> CGFloat {
        abs(CGFloat(index) - CGFloat(cardCount - 1) / 2) * 8
    }
}
