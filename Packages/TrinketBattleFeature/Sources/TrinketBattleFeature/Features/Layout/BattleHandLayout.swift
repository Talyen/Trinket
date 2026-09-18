import CoreGraphics
import TrinketContent
import TrinketFeatureSupport

enum BattleCoordinateSpace {
    static let field = "trinket.battle.field"
}

enum BattleHandLayout {
    static let minCardWidth: CGFloat = 156
    static let maxCardWidth: CGFloat = 220
    static let aspectRatio: CGFloat = 4.0 / 3.0
    static let widthRatio: CGFloat = 0.45
    static let horizontalInset: CGFloat = 20
    static let maxOverlapRatio: CGFloat = 0.45
    static let fanAngleStep: CGFloat = 9
    static let fanLiftStep: CGFloat = 10
    static let bottomRise: CGFloat = 30
    static let restingYFraction: CGFloat = 0.20
    struct Metrics: Equatable {
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let overlap: CGFloat
        let startX: CGFloat
    }

    static func metrics(
        containerWidth: CGFloat,
        cardCount: Int,
    ) -> Metrics {
        let cardWidth = min(
            maxCardWidth,
            max(minCardWidth, containerWidth * widthRatio),
        )
        let cardHeight = cardWidth * aspectRatio
        let overlap: CGFloat = cardCount > 1
            ? min(
                cardWidth * maxOverlapRatio,
                (containerWidth - cardWidth - horizontalInset * 2) / CGFloat(cardCount - 1),
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
        containerFrame: CGRect,
    ) -> CGPoint {
        let baseOffsetY = metrics.cardHeight * restingYFraction
            + restingOffsetY(
                index: index,
                cardCount: cardCount,
            )
        return CGPoint(
            x: containerFrame.midX + cardOffsetX(
                index: index,
                metrics: metrics,
                containerWidth: containerFrame.width,
            ),
            y: containerFrame.maxY - bottomRise - metrics.cardHeight / 2 + baseOffsetY,
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
