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
    /// Horizontal stride between consecutive cards as a fraction of card width.
    static let maxOverlapRatio: CGFloat = 0.40
    /// Degrees of fan rotation between adjacent cards.
    static let fanAngleStep: CGFloat = 9
    /// Extra drop for outer cards in the fan.
    static let fanLiftStep: CGFloat = 10
    /// Lifts the hand band off the bottom edge for better card visibility.
    static let bottomRise: CGFloat = 25
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
            startX: startX
        )
    }

    static func cardOffsetX(index: Int, metrics: Metrics, containerWidth: CGFloat) -> CGFloat {
        metrics.startX + CGFloat(index) * metrics.overlap - containerWidth / 2 + metrics.cardWidth / 2
    }

    static func rotation(index: Int, cardCount: Int) -> CGFloat {
        guard cardCount > 1 else { return 0 }
        return (CGFloat(index) - CGFloat(cardCount - 1) / 2) * fanAngleStep
    }

    static func restingOffsetY(index: Int, cardCount: Int) -> CGFloat {
        abs(CGFloat(index) - CGFloat(cardCount - 1) / 2) * fanLiftStep
    }

    static func shouldPlay(
        translation: CGSize,
        predictedEndTranslation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold
    ) -> Bool {
        guard isPlayable else { return false }
        let release = predictedEndTranslation.height < translation.height
            ? predictedEndTranslation
            : translation
        let upwardDistance = -release.height
        return upwardDistance >= threshold
            && upwardDistance > abs(release.width)
    }

    /// Keeps invalid upward drags responsive while progressively resisting the
    /// part of the gesture that would otherwise cross the play boundary.
    static func presentationTranslation(
        _ translation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold
    ) -> CGSize {
        guard !isPlayable, translation.height < 0 else { return translation }
        let upwardDistance = -translation.height
        guard upwardDistance > threshold else { return translation }
        let overshoot = upwardDistance - threshold
        let resistedOvershoot = overshoot * threshold / (threshold + overshoot * 1.8)
        return CGSize(
            width: translation.width * 0.72,
            height: -(threshold + resistedOvershoot)
        )
    }

    static func heldTilt(
        translation: CGSize,
        predictedEndTranslation: CGSize,
        cardWidth: CGFloat,
        maximumDegrees: Double
    ) -> Double {
        guard cardWidth > 0 else { return 0 }
        let velocityLean = Double(predictedEndTranslation.width - translation.width) * 0.04
        let positionLean = Double(translation.width / cardWidth) * maximumDegrees
        return min(max(positionLean + velocityLean, -maximumDegrees), maximumDegrees)
    }
}
