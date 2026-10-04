import CoreGraphics
import TrinketContent
import TrinketFeatureSupport

enum BattleCoordinateSpace {
    static let field = "trinket.battle.field"
}

enum BattleHandLayout {
    static let minCardWidth: CGFloat = 156
    static let maxCardWidth: CGFloat = 220
    /// Portrait height-to-width ratio for cards (4:3 portrait, height = width * aspectRatio).
    static let aspectRatio: CGFloat = 4.0 / 3.0
    static let widthRatio: CGFloat = 0.45
    static let horizontalInset: CGFloat = 20
    static let maxOverlapRatio: CGFloat = 0.45
    static let fanAngleStep: CGFloat = 9
    static let fanLiftStep: CGFloat = 10
    static let bottomRise: CGFloat = 30
    static let reservedHeight: CGFloat = 224
    static let overlapAllowance: CGFloat = 56
    static let restingYFraction: CGFloat = 0.20
    struct Metrics: Equatable {
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let overlap: CGFloat
        let startX: CGFloat
    }

    /// Keep compact hand geometry unchanged; grow the same fan in wider space.
    static func scale(for containerWidth: CGFloat) -> CGFloat {
        max(1, containerWidth / 700)
    }

    static func battlefieldSize(in containerSize: CGSize) -> CGSize {
        let handFrame = frame(in: containerSize)
        let existingHeight = containerSize.height - handFrame.height
            + overlapAllowance * scale(for: containerSize.width)
        guard containerSize.width > 500 else {
            return CGSize(width: containerSize.width, height: max(0, existingHeight))
        }

        // A wider portrait canvas must leave the party's resource bars above
        // the resting fan, including its rotation about each card's bottom.
        let metrics = metrics(containerWidth: containerSize.width, cardCount: 3)
        let cardBounds = CGRect(
            x: -metrics.cardWidth / 2,
            y: -metrics.cardHeight,
            width: metrics.cardWidth,
            height: metrics.cardHeight,
        )
        let handTop = (0 ..< 3).map { index in
            let center = restingCenter(index: index, metrics: metrics, cardCount: 3, handFrame: handFrame)
            let rotatedBounds = cardBounds.applying(CGAffineTransform(
                rotationAngle: rotation(index: index, cardCount: 3) * .pi / 180,
            ))
            return center.y + metrics.cardHeight / 2 + rotatedBounds.minY
        }.min() ?? handFrame.minY
        return CGSize(width: containerSize.width, height: max(0, min(existingHeight, handTop)))
    }

    static func frame(in containerSize: CGSize) -> CGRect {
        let scale = scale(for: containerSize.width)
        return CGRect(
            x: 0,
            y: containerSize.height - (reservedHeight + bottomRise) * scale,
            width: containerSize.width,
            height: reservedHeight * scale,
        )
    }

    static func metrics(
        containerWidth: CGFloat,
        cardCount: Int,
    ) -> Metrics {
        let scale = scale(for: containerWidth)
        let cardWidth = min(
            maxCardWidth * scale,
            max(minCardWidth * scale, containerWidth * widthRatio),
        )
        let cardHeight = cardWidth * aspectRatio
        let overlap: CGFloat = cardCount > 1
            ? min(
                cardWidth * maxOverlapRatio,
                (containerWidth - cardWidth - horizontalInset * 2 * scale) / CGFloat(cardCount - 1),
            )
            : 0
        let totalWidth = cardWidth + overlap * CGFloat(max(cardCount - 1, 0))
        let startX = (containerWidth - totalWidth) / 2
        return Metrics(
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            overlap: overlap,
            startX: startX,
        )
    }

    static func cardOffsetX(index: Int, metrics: Metrics, containerWidth: CGFloat) -> CGFloat {
        metrics.startX + CGFloat(index) * metrics.overlap - containerWidth / 2 + metrics.cardWidth / 2
    }

    static func restingCenter(
        index: Int,
        metrics: Metrics,
        cardCount: Int,
        handFrame: CGRect,
    ) -> CGPoint {
        let baseOffsetY = metrics.cardHeight * restingYFraction
            + restingOffsetY(
                index: index,
                cardCount: cardCount,
            )
        return CGPoint(
            x: handFrame.midX + cardOffsetX(
                index: index,
                metrics: metrics,
                containerWidth: handFrame.width,
            ),
            y: handFrame.maxY - metrics.cardHeight / 2 + baseOffsetY,
        )
    }

    static func releaseCenter(restingCenter: CGPoint, dragTranslation: CGSize) -> CGPoint {
        CGPoint(
            x: restingCenter.x + dragTranslation.width,
            y: restingCenter.y + dragTranslation.height,
        )
    }

    static func rotation(
        index: Int,
        cardCount: Int,
        fanAngleStep: CGFloat = Self.fanAngleStep,
    ) -> CGFloat {
        guard cardCount > 1 else { return 0 }
        return (CGFloat(index) - CGFloat(cardCount - 1) / 2) * fanAngleStep
    }

    static func restingOffsetY(
        index: Int,
        cardCount: Int,
        fanLiftStep: CGFloat = Self.fanLiftStep,
    ) -> CGFloat {
        abs(CGFloat(index) - CGFloat(cardCount - 1) / 2) * fanLiftStep
    }
}
